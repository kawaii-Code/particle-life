package particle_life

import "core:math"

screen_to_world :: proc(p: [2]i32, camera: MyCamera) -> [2]i32 {
    zoom_ratio_x := camera.width  / f32(viewport_width)
    zoom_ratio_y := camera.height / f32(viewport_height)

    x := f32(p.x) * zoom_ratio_x + camera.x
    y := world_size - f32(viewport_height - p.y) * zoom_ratio_y - camera.y
        
    return {i32(x), i32(y)} 
}

world_to_normalized :: proc(p: [2]i32) -> [2]f32 {
    np := [2]f32{f32(p.x), f32(p.y)} / f32(world_size)
    np.x -= math.trunc(np.x)
    np.y -= math.trunc(np.y)
    if np.x < 0 {
        np.x = 1.0 + np.x
    }
    if np.y < 0 {
        np.y = 1.0 + np.y
    }
    return np
}

normalized_to_world :: proc(p: [2]f32) -> [2]i32 {
    world_f := p * world_size
    return {i32(world_f.x), i32(world_f.y)}
}