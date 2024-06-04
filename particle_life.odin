package particle_life

import "core:math"
import "core:math/linalg"
import "core:fmt"
import "core:os"


particle_radius              : f32 = 4.0
particle_spawn_spread        :     : 0.01
particle_attraction_strength : f32 = 0.3
particle_repel_strength      :     : 0.2 
particle_air_resistance      : f32 = 20
particle_repel_distance      : f32 = 0.05
particle_max_distance        : f32 = 0.2
particle_color_count         :     : int(ParticleColor.Count)
particle_half_life           :     : 0.1

particle_max_velocity        :: 10.0

epsilon :: 0.0001

particle_attraction_table : [particle_color_count * particle_color_count]f32



ParticleColor :: enum {
    R, G, B, Y, P, W, Count
}

Particle :: struct {
    using pos: [2]f32,
    v: [2]f32,
    c: ParticleColor,
}



get_attraction_for :: proc(c1, c2: ParticleColor) -> f32 {
    return particle_attraction_table[int(c1) * particle_color_count + int(c2)]
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
    
    return linalg.normalize0(direction), math.sqrt(distance)
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
            attraction_color_coef := get_attraction_for(p1.c, p2.c)
            
            direction, distance := direction_and_distance_between(p1^, p2^)
            if distance > particle_max_distance {
                continue
            }
            
            if distance < particle_repel_distance {
                repel_direction := length2(direction) < epsilon ? rand_direction() : normalize(-1 * direction)
                f += particle_repel_strength * repel_direction * (1.0 - distance / particle_repel_distance)
            } else {
                attract_direction := length2(direction) < epsilon ? rand_direction() : normalize(direction)
                attraction_force : [2]f32

                middle := (particle_repel_distance + particle_max_distance) / 2
                half := (particle_max_distance - particle_repel_distance) / 2.0
                t := (1.0 - math.abs(middle - distance) / half)
                attraction_force = attract_direction * t
                f += particle_attraction_strength * attraction_color_coef * attraction_force
            }
           
            when ODIN_DEBUG {
                if math.is_nan(f.x) || math.is_nan(f.y) {
                    fmt.println("nan. direction = ", direction, "distance = ", distance)
                    os.exit(1)
                }
            }
        }

        p1.v = math.pow(0.5, dt / particle_half_life) * p1.v + f * dt
    }
}