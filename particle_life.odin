package main

import "core:math"
import "core:math/linalg"



particle_radius     : f32 = 4.0
particle_speed      :: 0.1
particle_spread     :: 0.01
particle_attraction_strength : f32 = 0.3
particle_repel_strength :     : 0.2 
particle_air_resistance : f32 = 20
particle_repel_distance : f32 = 0.05
particle_max_distance   : f32 = 0.2


epsilon :: 0.0001

color_count      :: 6
attraction_table : [color_count][color_count]f32



ParticleColor :: enum {
    R = 0, G, B, Y, P, W
}

Particle :: struct {
    using pos: [2]f32,
    v: [2]f32,
    c: ParticleColor,
}

wrap_particle_position :: proc(p: ^Particle) {
    if p.x < 0 {
        p.x = 1.0
    } else if p.x > 1.0 {
        p.x = 0
    }
    if p.y < 0 {
        p.y = 1.0
    } else if p.y > 1.0 {
        p.y = 0
    }
}

direction_and_distance_between :: proc(p1: [2]f32, p2: [2]f32) -> (direction: [2]f32, distance: f32) {
    direction = p2 - p1
    distance = linalg.length2(p2 - p1)
    if (p1.x < p2.x && p1.y < p2.y) {
        other := linalg.length2(p2 - (p1 + {1, 1}))
        if other < distance {
            distance = other
            direction = p2 - (p1 + {1, 1})
        }
    } else if (p1.x > p2.x && p1.y > p2.y) {
        other := linalg.length2((p2 + {1, 1}) - p1)
        if other < distance {
            distance = other
            direction = (p2 + {1, 1}) - p1
        }
    }
    
    if (p1.x < p2.x) {
        other := linalg.length2(p2 - (p1 + {1, 0}))
        if other < distance {
            distance = other
            direction = p2 - (p1 + {1, 0})
        }
    } else {
        other := linalg.length2((p2 + {1, 0}) - p1)
        if other < distance {
            distance = other
            direction = (p2 + {1, 0}) - p1
        }
    }

    if (p1.y < p2.y) {
        other := linalg.length2(p2 - (p1 + {0, 1}))
        if other < distance {
            distance = other
            direction = p2 - (p1 + {0, 1})
        }
    } else {
        other := linalg.length2((p2 + {0, 1}) - p1)
        if other < distance {
            distance = other
            direction = (p2 + {0, 1}) - p1
        }
    }
    
    return direction, math.sqrt(distance)
}

update_particles :: proc(particles: [dynamic]Particle, dt: f32) {
    using linalg

    for i := 0; i < len(particles); i += 1 {
        p1 := &particles[i]
        p1.pos += p1.v * dt
        wrap_particle_position(p1)
        
        f : [2]f32
        for j := 0; j < len(particles); j += 1 {
            if i == j {
                continue
            }
            p2 := &particles[j]
            attraction_color_coef := attraction_table[color_to_idx(p1.c)][color_to_idx(p2.c)]
            
            direction, distance := direction_and_distance_between(p1^, p2^)
            
            attraction_force : [2]f32
            if distance > particle_max_distance {
                attraction_force = 0
            } else if distance < particle_repel_distance {
                repel_direction := length(direction) < epsilon ? rand_direction() : normalize(-1 * direction)
                attraction_force = particle_repel_strength * repel_direction * (1.0 - distance / particle_repel_distance)
            } else {
                middle := (particle_repel_distance + particle_max_distance) / 2
                t := (1.0 - math.abs(middle - distance) / middle)
                attraction_force = normalize(direction) * t
            }
            
            f += particle_attraction_strength * attraction_color_coef * attraction_force
        }
        if length2(p1.v) > epsilon {
            f += -1 * normalize(p1.v) * particle_air_resistance * length2(p1.v)
        }
        p1.v += f * dt
    }
}