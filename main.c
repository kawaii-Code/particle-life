#include "render.c"
#include "particle-life.c"

#define WIDTH  800
#define HEIGHT 600
#define BACKGROUND_COLOR 0xFF222222

int pixels[WIDTH*HEIGHT];

void pixels_fill(int color) {
    for (size_t i = 0; i < WIDTH*HEIGHT; i++) {
        pixels[i] = color;
    }
}

void pixels_display_particle_at(int x, int y, Color particle_color) {
    for (int dy = y - 2; dy < y + 2; dy++) {
        if (dy < 0 || dy >= HEIGHT)
            continue;

        for (int dx = x - 2; dx < x + 2; dx++) {
            if (dx < 0 || dx >= WIDTH)
                continue;

            pixels[dy*WIDTH + dx] = 0xFF2222FF;
        }
    }
}

void pixels_display_particles() {
    const Particle *const particles = particles_get_all();
    
    for (int i = 0; i < COUNT; i++) {
        Particle p = particles[i];
        
        int x = p.x;
        int y = p.y;

        pixels_display_particle_at(x, y, p.color);
    }
}

int main() {
    render_init("Particle life", WIDTH, HEIGHT);
    particles_init(WIDTH, HEIGHT);

    int run = 1;
    SDL_Event e;
    while (run) {
        while (render_poll_event(&e)) {
            switch (e.type) {
                case SDL_KEYDOWN:
                    if (e.key.keysym.sym == SDLK_q)
                        run = 0;
            }
        }

        particles_update();

        pixels_fill(BACKGROUND_COLOR);
        pixels_display_particles();

        render_draw(pixels, WIDTH*4);
    }

    render_destroy();
}
