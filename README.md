# Particle Life

My implementation of the game of life variation, "Particle Life", in C


## Rules

In particle life, we spawn a bunch of particles:
they each have a position, a velocity and a color.
They can attract or repel neighboring particles.
This attraction force is determined by the color of the particle:
for each pair of colors, we have an *attraction factor* that
tells us how strong the force between particles of these colors is.


## Installation

If you want to play this on your machine, you can build it from source:

```
git clone https//github.com/kawaii-Code/particle-life
cd particle-life
make
```

**THIS IS NOT ALL**

This app depends on [SDL](https://github.com/libsdl-org/SDL), 
download any of 2.26.x releases and put the SDL2.dll file in the 
project's root folder.


## Inspiration

[Tom Mohr's video](https://www.youtube.com/watch?v=p4YirERTVF0) introduced me to this awesome game.
