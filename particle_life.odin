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
particle_half_life           :     : 0.05

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

wrap_position :: proc(p: ^[2]f32) {
    if p.x < 0 {
        p.x += 1.0
    } else if p.x > 1.0 {
        p.x -= 1.0
    }
    if p.y < 0 {
        p.y += 1.0
    } else if p.y > 1.0 {
        p.y -= 1.0
    }
}

direction_and_distance_between :: proc(p1, p2: [2]f32) -> (direction: [2]f32, distance: f32) {
    abs_min :: proc(x, y: f32) -> f32 {
        if math.abs(x) < math.abs(y) {
            return x
        }
        return y
    }

    d := p2 - p1
    
    dx := abs_min(d.x, abs_min(d.x + 1, d.x - 1))
    dy := abs_min(d.y, abs_min(d.y + 1, d.y - 1))
        
    return linalg.normalize([2]f32{dx, dy}), math.sqrt(dx*dx + dy*dy)
}

update_particles :: proc(particles: #soa[dynamic]Particle, forces_buffer: [dynamic][2]f32, dt: f32) {
    for _, i in forces_buffer {
        forces_buffer[i] = {0, 0}
    }
 
    using linalg

    for &p1, i in particles {
        p1.pos += p1.v * dt
        wrap_position(&p1.pos)
        
        for &p2, j in particles[i+1:] {
            attraction_color_coef := get_attraction_for(p1.c, p2.c)
            
            direction, distance := direction_and_distance_between(p1, p2)
            if distance > particle_max_distance {
                continue
            }
            
            force: [2]f32
            if distance < particle_repel_distance {
                repel_direction := length2(direction) < epsilon ? rand_direction() : normalize(-1 * direction)
                force = particle_repel_strength * repel_direction * (1.0 - distance / particle_repel_distance)
            } else {
                attract_direction := length2(direction) < epsilon ? rand_direction() : normalize(direction)
                attraction_force : [2]f32

                middle := (particle_repel_distance + particle_max_distance) / 2
                half := (particle_max_distance - particle_repel_distance) / 2.0
                t := (1.0 - math.abs(middle - distance) / half)
                attraction_force = attract_direction * t
                
                force = particle_attraction_strength * attraction_color_coef * attraction_force
            }
            
            forces_buffer[i] += force
            forces_buffer[i + j + 1] -= force
           
            when ODIN_DEBUG {
                if math.is_nan(forces_buffer[i].x) || math.is_nan(forces_buffer[i].y) {
                    fmt.println("nan. direction = ", direction, "distance = ", distance)
                    os.exit(1)
                }
            }
        }
    }
    
    for &p, i in particles {
        p.v = math.pow(0.5, dt / particle_half_life) * p.v + forces_buffer[i] * dt
    }
}