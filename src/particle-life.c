#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <float.h>
#include <math.h>

typedef enum {
    RED    = 0xFF2222EE, // #EE2222
    ORANGE = 0xFF2288EE, // #EE8822
    YELLOW = 0xFF22EEEE, // #EEEE22
    GREEN  = 0xFF22EE22, // #22EE22
    BLUE   = 0xFFEE2222, // #2222EE
    PURPLE = 0xFFEE2288, // #8822EE
} Color; // A color in ABGR format

typedef enum {
    RED_INDEX    = 0,
    ORANGE_INDEX = 1,
    YELLOW_INDEX = 2,
    GREEN_INDEX  = 3,
    BLUE_INDEX   = 4,
    PURPLE_INDEX = 5,
    COLOR_COUNT  = 6
} ColorIndex;

typedef struct {
    int x, y;
    int dx, dy;
    Color color;
} Particle;

int particles_color_by_index(ColorIndex index) {
    if (index == RED_INDEX)
        return RED;
    if (index == ORANGE_INDEX)
        return ORANGE;
    if (index == YELLOW_INDEX)
        return YELLOW;
    if (index == GREEN_INDEX)
        return GREEN;
    if (index == BLUE_INDEX)
        return BLUE;
    if (index == PURPLE_INDEX)
        return PURPLE;
    return -1;
}

int particles_get_color_index(Particle *p) {
    Color color = p->color;

    if (color == RED)
        return RED_INDEX;
    if (color == ORANGE)
        return ORANGE_INDEX;
    if (color == YELLOW)
        return YELLOW_INDEX;
    if (color == GREEN)
        return GREEN_INDEX;
    if (color == BLUE)
        return BLUE_INDEX;
    if (color == PURPLE)
        return PURPLE_INDEX;
    return -1;
}

#define PARTICLE_COUNT 400
#define PARTICLE_VIRTUAL_SCALE 50

static Particle particles[PARTICLE_COUNT];
static int width;
static int height;
static int halfWidth;
static int halfHeight;
static int spawnIndex = 0;

void particles_setup(size_t pixels_width, size_t pixels_height) {
    width = pixels_width * PARTICLE_VIRTUAL_SCALE;
    height = pixels_height * PARTICLE_VIRTUAL_SCALE;
    halfWidth = width / 2;
    halfHeight = height / 2;
    
    for (size_t i = 0; i < PARTICLE_COUNT; i++) {
        Particle particle;
        particle.x = rand() * width  / RAND_MAX - halfWidth;
        particle.y = rand() * height / RAND_MAX - halfHeight;

        int r = COLOR_COUNT * rand() / RAND_MAX;
        particle.color = particles_color_by_index(r);

        particles[i] = particle;
    }
}

void particles_spawn(int x, int y, Color color) {
    int virX = PARTICLE_VIRTUAL_SCALE * x - halfWidth;
    int virY = PARTICLE_VIRTUAL_SCALE * y - halfHeight;
    Particle particle = {
        .x = virX, 
        .y = virY,
        .dx = 0,   
        .dy = 0,
        .color = color,
    };

    particles[(spawnIndex = (spawnIndex + 1) % PARTICLE_COUNT)] = particle;
}

const Particle *particles_get_all() {
    return particles;
}

#define RMIN  (PARTICLE_VIRTUAL_SCALE * 10.0)
#define RMAX  (PARTICLE_VIRTUAL_SCALE * 200.0)
#define RBEST ((RMIN + RMAX) / 2)
#define MAX_ATTRACTION_FORCE   10.0
#define UNIVERSAL_REPEL_FORCE  50.0
#define UNIVERSAL_FRICTION     0.6

//    | R | O | Y | G | B | P |
//  R |                       |
//  O |                       |
//  Y |                       |
//  G |                       |
//  B |                       |
//  P |                       |
float ParticlesAttractionMatrix[COLOR_COUNT][COLOR_COUNT] =
{
    {  1.0,  0.5,  0.0,  0.5,  0.0,  0.0 },

    {  0.0,  1.0,  0.5,  0.0,  0.0,  0.0 },

    {  0.0,  0.0,  1.0,  0.5,  0.0,  0.0 },

    {  0.0,  0.0,  0.0,  1.0,  0.5,  0.0 },

    {  0.0,  0.0,  0.0,  0.0,  1.0,  0.5 },

    {  0.5,  0.0,  0.0,  0.0,  0.0,  1.0 },
};

void particles_randomize_matrix() {
    for (int i = 0; i < COLOR_COUNT; i++) {
        for (int j = 0; j < COLOR_COUNT; j++) {
            float randomValue = (200.0 * rand() / RAND_MAX) / 100.0 - 1.0;
            ParticlesAttractionMatrix[i][j] = randomValue;
        }
    }
}

float particles_get_force(Particle *from, Particle *to) {
    int indexFrom = particles_get_color_index(from);
    int indexTo = particles_get_color_index(to);

    return MAX_ATTRACTION_FORCE * ParticlesAttractionMatrix[indexTo][indexFrom];
}

int particles_wrap_coordinate(int c, int border) {
    int sign = c < 0 ? -1 : 1;
    int halfBorder = border/2;

    return (c + sign*halfBorder) % border - sign*halfBorder;
}

void particles_velocity_from_to(Particle *from, Particle *to, float *resDX, float *resDY) {
    int dstX = from->x - to->x;
    int dstY = from->y - to->y;
    int wx = -particles_wrap_coordinate(dstX, width); 
    int wy = -particles_wrap_coordinate(dstY, height);
    float dist = sqrt(wx*wx + wy*wy);

    if (dist > RMAX) {
        *resDX = 0;
        *resDY = 0;
        return;
    }

    float angle = 0;
    if (abs(wx) > 1e-10)
        angle = atan2f(wy, wx);
    float force;

    if (dist <= RMIN) {
        force = -1 * UNIVERSAL_REPEL_FORCE * (1 - dist / RMIN);
    }
    else if (dist <= RBEST) {
        float color_attraction = particles_get_force(from, to);
        force = color_attraction * (dist - RMIN) / (RBEST - RMIN);
    }
    else {
        float color_attraction = particles_get_force(from, to);
        force = color_attraction * (RMAX - dist) / (RMAX - RBEST);
    }

    *resDX = force * cosf(angle);
    *resDY = force * sinf(angle);
}

void particles_update() {
    for (int i = 0; i < PARTICLE_COUNT; i++) {
        Particle particle = particles[i];
        particle.x += particle.dx;
        particle.y += particle.dy;
        particle.x = particles_wrap_coordinate(particle.x, width);
        particle.y = particles_wrap_coordinate(particle.y, height);
        
        float newDX = particle.dx * UNIVERSAL_FRICTION;
        float newDY = particle.dy * UNIVERSAL_FRICTION;
        for (int j = 0; j < PARTICLE_COUNT; j++) {
            if (i == j)
                continue;
            Particle other = particles[j];

            float vx, vy;
            particles_velocity_from_to(&particle, &other, &vx, &vy);

            newDX += vx;
            newDY += vy;
        }

        particle.dx = (int) newDX;
        particle.dy = (int) newDY;
        particles[i] = particle;
    }
}
