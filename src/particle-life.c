#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <float.h>
#include <math.h>

// #E39483
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

#define PARTICLE_COUNT 100
#define PARTICLE_VIRTUAL_SCALE 30

static Particle particles[PARTICLE_COUNT];
static int width;
static int height;

void particles_setup(size_t pixels_width, size_t pixels_height) {
    width = pixels_width * PARTICLE_VIRTUAL_SCALE;
    height = pixels_height * PARTICLE_VIRTUAL_SCALE;
    
    for (size_t i = 0; i < PARTICLE_COUNT; i++) {
        Particle particle;
        particle.x = rand() * width / RAND_MAX - width/2;
        particle.y = rand() * height / RAND_MAX - height/2;

        int r = 8 * rand() / RAND_MAX;
        if (r < 3)
            particle.color = GREEN;
        else if (r < 8)
            particle.color = RED;

        particles[i] = particle;
    }
}

const Particle *particles_get_all() {
    return particles;
}

#define RMIN  (PARTICLE_VIRTUAL_SCALE * 40.0)
#define RMAX  (PARTICLE_VIRTUAL_SCALE * 150.0)
#define RBEST ((RMIN + RMAX) / 2)
#define UNIVERSAL_REPEL_FORCE  20.0
#define UNIVERSAL_FRICTION     0.75

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

//    | R | O | Y | G | B | P |
//  R |                       |
//  O |                       |
//  Y |                       |
//  G |                       |
//  B |                       |
//  P |                       |
float ParticlesAttractionMatrix[COLOR_COUNT][COLOR_COUNT] =
{
    { 5*9.0,   0.0,   0.0, 9*5.0,   0.0,   0.0 },

    {   0.0,   0.0,   0.0,   0.0,   0.0,   0.0 },

    {   0.0,   0.0,   0.0,   0.0,   0.0,   0.0 },

    {8*-9.0,   0.0,   0.0, 3*9.0,   0.0,   0.0 },

    {   0.0,   0.0,   0.0,   0.0,   0.0,   0.0 },

    {   0.0,   0.0,   0.0,   0.0,   0.0, 3*6.0 },
};

float particles_get_force(Particle *from, Particle *to) {
    int indexFrom = particles_get_color_index(from);
    int indexTo = particles_get_color_index(to);

    return ParticlesAttractionMatrix[indexTo][indexFrom];
}

void particles_wrap(Particle *particle) {
    if (particle->x <= -width/2)
        particle->x = width/2;
    else 
        particle->x = (particle->x + width/2) % width - width/2;

    if (particle->y <= -height/2)
        particle->y = height/2;
    else
        particle->y = (particle->y + height/2) % height - height/2;
}

void particles_update() {
    for (int i = 0; i < PARTICLE_COUNT; i++) {
        Particle particle = particles[i];

        particle.x += particle.dx;
        particle.y += particle.dy;
        particles_wrap(&particle);
        particle.dx *= UNIVERSAL_FRICTION;
        particle.dy *= UNIVERSAL_FRICTION;

        float ndx = 0;
        float ndy = 0;
        for (int j = 0; j < PARTICLE_COUNT; j++) {
            if (i == j)
                continue;

            Particle other = particles[j];
            int x1 = particle.x, x2 = other.x;
            int y1 = particle.y, y2 = other.y;
            int dx = x2 - x1;
            int dy = y2 - y1;

            int signX = dx < 0 ? -1 : 1;
            int signY = dy < 0 ? -1 : 1;
            int wx = ((dx + signX * width/2) % width - signX * width/2);
            int wy = ((dy + signY * height/2) % height - signY * height/2);
            float dist = sqrt(wx*wx + wy*wy);

            if (dist > RMAX)
                continue;

            float angle = atan2f(wy, wx);
            float force;
            
            if (dist < RMIN) {
                force = UNIVERSAL_REPEL_FORCE * (-(RMIN / dist));
            }
            else if (dist <= RBEST) {
                float distInMin = dist - RMIN;
                float distInBest = RBEST - RMIN;

                float color_force = particles_get_force(&particle, &other);

                force = color_force * (1 + distInMin / distInBest);
            } else {
                float distInMin = RMAX - dist;
                float distInBest = RMAX - RBEST;

                float color_force = particles_get_force(&particle, &other);

                force = color_force * (1 - distInMin / distInBest);
            }

            ndx = force * cosf(angle);
            ndy = force * sinf(angle);
        }

        particle.dx += (int) ndx;
        particle.dy += (int) ndy;

        particles[i] = particle;
    }
}
