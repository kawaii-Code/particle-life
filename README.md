# [WIP] Particle Life

## Rules

In particle life, we spawn a bunch of particles:
they each have a position, a velocity and a color.
They can attract or repel neighbouring particles.
This attraction force is determined by the color of the particle:
for each pair of colors, we have an *attraction factor* that
tells us how strong the force between particles of these colors is.

## Quick Start

`odin run . -o:speed`

## Inspiration

[Tom Mohr's video](https://www.youtube.com/watch?v=p4YirERTVF0) introduced me to this awesome game.