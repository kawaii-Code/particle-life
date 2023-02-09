#include <stdint.h>
#include <stdlib.h>

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

#define COUNT 100

static Particle particles[COUNT];
static int width;
static int height;

void particles_setup(size_t pixels_width, size_t pixels_height) {
    width = pixels_width;
    height = pixels_height;

    for (size_t i = 0; i < COUNT; i++) {
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

        particle.color = RED;
        particles[i] = particle;
    }
}

const Particle *const particles_get_all() {
    return particles;
}

void particles_update() {
    for (int i = 0; i < COUNT; i++) {
        Particle particle = particles[i];

        particle.x += particle.dx;
        particle.y += particle.dy;

        if (particle.x >= width - 1 || particle.x <= 0) {
            particle.dx *= -1;
        }

        if (particle.y >= height - 1 || particle.y <= 0) {
            particle.dy *= -1;
        }

        particles[i] = particle;

    }
}
