#include <stdio.h>
#include "render.c"
#include "particle-life.c"

#define WIDTH  1080
#define HEIGHT 1080
#define BACKGROUND_COLOR 0xFF222222

int pixels[WIDTH*HEIGHT];

void fill_backround(int color) {
    for (size_t i = 0; i < WIDTH*HEIGHT; i++) {
        pixels[i] = color;
    }
}

int particle_brightness[5][5] =
{
    { 5, 3, 2, 3, 5 },
    { 3, 2, 1, 2, 3 },
    { 3, 1, 1, 1, 3 },
    { 3, 2, 1, 2, 3 },
    { 5, 3, 2, 3, 5 },
};

void draw_particle(int x, int y, Color particle_color) {
    int countY = 0;
    int countX = 0;
    for (int dy = y - 2; dy <= y + 2; dy++, countY++) {
        if (dy < 0 || dy >= HEIGHT)
            continue;

        countX = 0;
        for (int dx = x - 2; dx <= x + 2; dx++, countX++) {
            if (dx < 0 || dx >= WIDTH)
                continue;

            int brightness = particle_brightness[countY][countX];
            Color color = particle_color;

            int r = (color >> 0*8) & 0xFF / brightness;
            int g = (color >> 1*8) & 0xFF / brightness;
            int b = (color >> 2*8) & 0xFF / brightness;
            int res = r | g << 8 | b << 16 | 255 << 24;

            pixels[dy*WIDTH + dx] = res;
        }
    }
}

void draw_particles() {
    const Particle *particles = particles_get_all();
    
    for (int i = 0; i < PARTICLE_COUNT; i++) {
        Particle p = particles[i];
        
        float x = (float)WIDTH/2  + (float)p.x / (float)PARTICLE_VIRTUAL_SCALE;
        float y = (float)HEIGHT/2 + (float)p.y / (float)PARTICLE_VIRTUAL_SCALE;
        
        draw_particle(round(x), round(y), p.color);
    }
}

void spawn_particle(int x, int y, int button) {
    if (button == SDL_BUTTON_LEFT)
        particles_spawn(x, y, RED);
    else if (button == SDL_BUTTON_RIGHT)
        particles_spawn(x, y, GREEN);
}

int main() {
    render_init("Particle life", WIDTH, HEIGHT);
    particles_setup(WIDTH, HEIGHT);

    int run = 1;
    SDL_Event e;
    while (run) {
        while (render_poll_event(&e)) {
            switch (e.type) {
                case SDL_KEYDOWN:
                    if (e.key.keysym.sym == SDLK_q)
                        run = 0;
                    if (e.key.keysym.sym == SDLK_r)
                        particles_randomize_matrix();
                    break;
                case SDL_MOUSEBUTTONDOWN:
                    spawn_particle(e.button.x, e.button.y, e.button.button);
                    break;
            }
        }

        particles_update();

        fill_backround(BACKGROUND_COLOR);
        draw_particles();

        render_draw(pixels, WIDTH*4);
    }

    render_destroy();
}
