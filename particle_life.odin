package particle_life

import "core:math"
import "core:math/linalg"
import "core:fmt"
import "core:os"
import "core:sync"



particle_radius              : f32 = 4.0
particle_spawn_spread        :     : 0.01
particle_attraction_strength : f32 = 0.3
particle_repel_strength      :     : 0.2 
particle_air_resistance      : f32 = 20
particle_repel_distance      : f32 = 0.01
particle_max_distance        : f32 = 0.03
particle_color_count         :     : int(ParticleColor.Count)
particle_half_life           :     : 0.1
particle_max_velocity        :: 10.0
particle_attraction_table : [particle_color_count * particle_color_count]f32

epsilon :: 0.0001

grid_size  :: 8
world_size :: 4000



World :: struct {
    particle_count : int,
    grid: [grid_size][grid_size]^Particle,
};

ParticleColor :: enum {
    R, G, B, Y, P, W, Count
}

Particle :: struct {
    next: ^Particle,
    prev: ^Particle,
    using pos: [2]f32,
    v: [2]f32,
    f: [2]f32,
    c: ParticleColor,
}



world_create :: proc() -> World {
    return World {}
}

world_destroy :: proc(world: ^World) {
    particles_free(world)
}

particles_free :: proc(world: ^World) {
    for i := 0; i < grid_size; i += 1 {
        for j := 0; j < grid_size; j += 1 {
            p := world.grid[i][j]
            for p != nil {
                next := p.next
                free(p)
                p = next
            }
            world.grid[i][j] = nil
        }
    }
    world.particle_count = 0
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

world_clear_particles :: proc(world: ^World) {
    particles_free(world)
}

world_add_particle :: proc(world: ^World, particle: Particle) {
    new_particle := new_clone(particle)
    grid_pos := to_grid(particle.pos)
    insert_in_grid(world, grid_pos, new_particle)
    world.particle_count += 1
}

accumulate_force_from_cell :: proc(world: ^World, p1: ^Particle, cell_start: ^Particle) {
    using linalg
    
    p2 := cell_start
    for p2 != nil {
        defer p2 = p2.next
        direction, dist := direction_and_distance_between(p1, p2)
        if dist > particle_max_distance {
            continue
        }

        if dist < particle_repel_distance {
            repel_direction := length2(direction) < epsilon ? rand_direction() : normalize(-1 * direction)
            force := particle_repel_strength * repel_direction * (1.0 - dist / particle_repel_distance)
            p1.f += force
            p2.f -= force
        } else {
            attract_direction := length2(direction) < epsilon ? rand_direction() : normalize(direction)
            
            middle := (particle_repel_distance + particle_max_distance) / 2
            half := (particle_max_distance - particle_repel_distance) / 2.0
            t := (1.0 - math.abs(middle - dist) / half)

            force := t * particle_attraction_strength * attract_direction
            
            p1_to_p2 := attraction_factor_between(p1.c, p2.c)
            p2_to_p1 := attraction_factor_between(p2.c, p1.c)
            p1.f += p1_to_p2 * force
            p2.f -= p2_to_p1 * force
        }
    }
}

get_cell :: proc(world: ^World, row, col: int) -> ^Particle {
    wrapped_row := (row + grid_size) % grid_size
    wrapped_col := (col + grid_size) % grid_size
    return world.grid[wrapped_row][wrapped_col]
}

world_update :: proc(world: ^World, dt: f32) {
    for row := 0; row < grid_size; row += 1 {
        for col := 0; col < grid_size; col += 1 {
            p1 := world.grid[row][col]
            for p1 != nil {
                // x x
                // x o
                // x
                accumulate_force_from_cell(world, p1, p1.next)
                accumulate_force_from_cell(world, p1, get_cell(world, row - 1, col))
                accumulate_force_from_cell(world, p1, get_cell(world, row - 1, col - 1))
                accumulate_force_from_cell(world, p1, get_cell(world, row    , col - 1))
                accumulate_force_from_cell(world, p1, get_cell(world, row + 1, col - 1))
                p1 = p1.next
            }
        }
    }

    for i := 0; i < grid_size; i += 1 {
        for j := 0; j < grid_size; j += 1 {
            p := world.grid[i][j]
            for p != nil {
                p.v = math.pow(0.5, dt / particle_half_life) * p.v + p.f * dt
                p.f = {0, 0}
                p.pos += p.v * dt
                wrap_position(&p.pos)
                p = p.next
            }
        }
    }
    
    for i := 0; i < grid_size; i += 1 {
        for j := 0; j < grid_size; j += 1 {
            p := world.grid[i][j]
            for p != nil {
                next := p.next
                reposition_in_grid(world, [2]int{i, j}, p)
                p = next
            }
        }
    }
}

to_grid :: proc(p: [2]f32) -> [2]int {
    return [2]int{
        clamp(int(p.y * grid_size), 0, grid_size - 1),
        clamp(int(p.x * grid_size), 0, grid_size - 1)
    }
}

insert_in_grid :: proc(world: ^World, grid_pos: [2]int, p: ^Particle) {
    grid_cell := world.grid[grid_pos.x][grid_pos.y]
    if grid_cell != nil {
        grid_cell.prev = p
    }
    p.next = grid_cell
    p.prev = nil
    world.grid[grid_pos.x][grid_pos.y] = p
}

reposition_in_grid :: proc(world: ^World, old_grid_pos: [2]int, p: ^Particle) {
    new_grid_pos := to_grid(p.pos)
    if new_grid_pos != old_grid_pos {
        if p.prev != nil {
            p.prev.next = p.next
        } else {
            world.grid[old_grid_pos.x][old_grid_pos.y] = p.next
        }
        if p.next != nil {
            p.next.prev = p.prev
        }
        
        insert_in_grid(world, new_grid_pos, p)
    }
}
  
attraction_factor_between :: proc(c1, c2: ParticleColor) -> f32 {
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
