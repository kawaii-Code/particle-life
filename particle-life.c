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

#define PARTICLE_COUNT 100

static Particle particles[PARTICLE_COUNT];
static int width;
static int height;

void particles_setup(size_t pixels_width, size_t pixels_height) {
    width = pixels_width;
    height = pixels_height;

    for (size_t i = 0; i < PARTICLE_COUNT; i++) {
        Particle particle;
        particle.x = rand() * width / RAND_MAX;
        particle.y = rand() * height / RAND_MAX;
    
        int randMaxD3 = RAND_MAX / 3;
        int randMax2D3 = 2 * randMaxD3;
    
        int randDx = rand();
        if (randDx > randMaxD3) {
            if (randDx > randMax2D3) {
                particle.dx = 1;
            } else {
                particle.dx = 0;
            }
        } else {
            particle.dx = -1;
        }

        int randDy = rand();
        if (randDy > randMaxD3) {
            if (randDy > randMax2D3) {
                particle.dy = 1;
            } else {
                particle.dy = 0;
            }
        } else {
            particle.dy = -1;
        }

        particle.color = 4 * rand() / RAND_MAX == 1 ? GREEN : RED;
        particles[i] = particle;
    }
}

const Particle *particles_get_all() {
    return particles;
}

#define RMIN 10.0
#define RMAX 300.0

#define RED_TO_RED_FORCE        2.0
#define RED_TO_GREEN_FORCE     -7.0
#define GREEN_TO_RED_FORCE      2.0
#define GREEN_TO_GREEN_FORCE   -2.0

#define UNIVERSAL_REPEL_FORCE  -8.0
#define UNIVERSAL_FRICTION      0.5

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

void particles_update() {
    for (int i = 0; i < PARTICLE_COUNT; i++) {
        Particle particle = particles[i];

        particle.x += particle.dx;
        particle.y += particle.dy;
        if (particle.x < 0)
            particle.x = width + particle.x;
        if (particle.y < 0)
            particle.y = height + particle.y;
        particle.x = particle.x % width;
        particle.y = particle.y % height;

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

            float dist = sqrt(dx*dx + dy*dy);

            if (dist > RMAX)
                continue;

            float angle = atan2f(dy, dx);
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
