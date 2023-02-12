#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <float.h>
#include <math.h>

typedef enum {
    RED    = 0xFF2222EE,
    ORANGE = 0xFF2288EE,
    YELLOW = 0xFF22EEEE,
    GREEN  = 0xFF22EE22,
    BLUE   = 0xFFEE2222,
    PURPLE = 0xFFEE2288,
} Color;

typedef struct {
    int x, y;
    int dx, dy;
    Color color;
} Particle;

#define PARTICLE_COUNT 200
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

        particle.color = 4 * rand() / RAND_MAX == 1 ? GREEN : RED;
        particles[i] = particle;
    }
}

const Particle *particles_get_all() {
    return particles;
}

#define RMIN PARTICLE_VIRTUAL_SCALE * 5.0
#define RMAX PARTICLE_VIRTUAL_SCALE * 150.0

#define RED_TO_RED_FORCE       9.0
#define RED_TO_GREEN_FORCE     -7.0
#define GREEN_TO_RED_FORCE     5.0
#define GREEN_TO_GREEN_FORCE   9.0

#define UNIVERSAL_REPEL_FORCE  15.0
#define UNIVERSAL_FRICTION     0.5

float particles_get_force(Particle *from, Particle *to) {
    if (from->color == RED && to->color == RED)
        return RED_TO_RED_FORCE;
    if (from->color == RED && to->color == GREEN)
        return RED_TO_GREEN_FORCE;
    if (from->color == GREEN && to->color == RED)
        return GREEN_TO_RED_FORCE;
    if (from->color == GREEN && to->color == GREEN)
        return GREEN_TO_GREEN_FORCE;
    return 0.0;
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

            int wx = -1 * ((dx + width/2) % width - width/2);
            int wy = -1 * ((dy + height/2) % height - height/2);
            float dist = sqrt(wx*wx + wy*wy);

            if (dist > RMAX)
                continue;

            float angle = atan2f(wy, wx);
            float bestDist = (RMAX + RMIN) / 2;
            float force;
            
            if (dist < RMIN) {
                force = UNIVERSAL_REPEL_FORCE * (1 + (dist*dist) / (RMIN*RMIN));
            }
            else if (dist <= bestDist) {
                float distInMin = dist - RMIN;
                float distInBest = bestDist - RMIN;

                float color_force = particles_get_force(&particle, &other);

                force = color_force * distInMin / distInBest;

            } else {
                float distInMin = RMAX - dist;
                float distInBest = RMAX - bestDist;

                float color_force = particles_get_force(&particle, &other);

                force = color_force * (1 - distInMin / distInBest);
            }

            ndx += force * cosf(angle);
            ndy += force * sinf(angle);
        }

        particle.dx = (int) ndx;
        particle.dy = (int) ndy;

        particles[i] = particle;
    }
}
