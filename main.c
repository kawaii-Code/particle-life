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
        particles_draw_all(pixels, WIDTH, HEIGHT);

        render_draw(pixels, WIDTH*4);
    }

    render_destroy();
}
