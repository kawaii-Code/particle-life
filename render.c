#define SDL_MAIN_HANDLED
#include "SDL.h"

#define FPS 60

static SDL_Window   *window;
static SDL_Renderer *renderer;
static SDL_Texture  *renderTexture;
    
void render_init(const char *winName, int winWindth, int winHeight) {
    SDL_Init(SDL_INIT_VIDEO);

    window = SDL_CreateWindow(
            winName, 
            SDL_WINDOWPOS_CENTERED, 
            SDL_WINDOWPOS_CENTERED, 
            winWindth, 
            winHeight, 
            SDL_WINDOW_OPENGL | SDL_WINDOW_BORDERLESS);

    renderer = SDL_CreateRenderer(
            window, 
            -1, 
            SDL_RENDERER_ACCELERATED);

    renderTexture = SDL_CreateTexture(
            renderer, 
            SDL_PIXELFORMAT_RGBA32, 
            SDL_TEXTUREACCESS_STREAMING, 
            winWindth, winHeight);
}

void render_destroy() {
    SDL_DestroyTexture(renderTexture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
}

void render_draw(void *pixels, int pinch) {
    SDL_UpdateTexture(renderTexture, NULL, pixels, pinch);
    SDL_RenderCopy(renderer, renderTexture, NULL, NULL);
    SDL_RenderPresent(renderer);

    SDL_Delay(1000 / FPS);
}

int render_poll_event(SDL_Event* event) {
    return SDL_PollEvent(event);
}
