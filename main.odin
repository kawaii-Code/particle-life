/*

TODO:
- Performance
  - Spatial partitioning
  - Multiple threads

- Do physics in a separate thread with a fixed timestep

- Better Controls
  - Zoom at mouse
  - Better zoom function
  - Scale camera speed with zoom

*/


package particle_life

import "core:fmt"
import "core:mem"
import "core:os"
import "core:math"
import "core:math/linalg"
import "core:math/rand"

import rl "vendor:raylib"



colors_table     : [particle_color_count]rl.Color = { rl.RED, rl.GREEN, rl.BLUE, rl.YELLOW, rl.PURPLE, rl.WHITE }

world_size      :: 2000

window_width    : i32 = 1000
window_height   : i32 = 600

viewport_width  : i32 = 800
viewport_height : i32 = 600
viewport_bg     :     : rl.Color{10, 10, 10, 255}

ui_width_ratio  :: 0.25
ui_panel_width  :: 250
ui_panel_height :: 600
ui_panel_bg     :: rl.Color{40, 40, 40, 255}
ui_font         :: "CourierPrime.ttf"
ui_font_size    :: 16
ui_element_height :: 10
ui_vertical_pad   :: 2

camera_movement_keys : []rl.KeyboardKey : { .W, .A, .S, .D }
camera_slow_speed    :: 500
camera_fast_speed    :: 1250
camera_zoom_speed    :: 5
camera_min_zoom      :: 0.33
camera_max_zoom      :: 5.0



PlayerState :: struct {
    tracked_particle_index : Maybe(int),
    active_color           : Maybe(ParticleColor),
    adjusting_color        : Maybe([2]int),
    selecting_color        : bool,
    ui_disabled            : bool,
    simulation_paused      : bool,
    click_spawn_count      : f32,
}

MyCamera :: struct {
    using rect: rl.Rectangle,
    zoom: f32,
}



main :: proc() {
    when ODIN_DEBUG {
        tracking_allocator: mem.Tracking_Allocator
        mem.tracking_allocator_init(&tracking_allocator, context.allocator)
        context.allocator = mem.tracking_allocator(&tracking_allocator)   
        defer {
            has_leaks := check_leaks(&tracking_allocator)
            mem.tracking_allocator_destroy(&tracking_allocator)
            os.exit(1 if has_leaks else 0)
        }
    }
    
    using rl

    SetConfigFlags(ConfigFlags {.WINDOW_RESIZABLE})
    InitWindow(window_width, window_height, "particle life")
    defer CloseWindow()

    SetTargetFPS(240)

    target := LoadRenderTexture(world_size, world_size)
    font := LoadFontEx(ui_font, ui_font_size, nil, 0)
    
    camera := MyCamera{rect = Rectangle{0, 0, f32(viewport_width), f32(viewport_height)}, zoom = 1.0}
    resize_window_elements(window_width, window_height, &camera)
   
    player : PlayerState
    player.click_spawn_count = 1

    particles : [dynamic]Particle
    defer delete(particles)

    fill_with_random_values(&particle_attraction_table, -1.0, 1.0)

    render_time := 0.0
    for !WindowShouldClose() {
        dt := GetFrameTime()
        
        if IsWindowResized() {
            resize_window_elements(GetScreenWidth(), GetScreenHeight(), &camera)
        }
        
        mouse_wheel := GetMouseWheelMove()
        if mouse_wheel != 0 {
            camera.zoom -= camera.zoom*camera.zoom * camera_zoom_speed * mouse_wheel * dt
            camera.zoom = clamp(camera.zoom, camera_min_zoom, camera_max_zoom)
            adjust_camera(&camera)   
        }
        key_to_direction :: proc(key: KeyboardKey) -> [2]f32 {
            #partial switch (key) {
                case .W: return {0, 1}
                case .A: return {-1, 0}
                case .S: return {0, -1}
                case .D: return {1, 0}
                case: assert(false)
            }
            return {0, 0}
        }
        camera_direction := [2]f32{0, 0}
        for key in camera_movement_keys {
            if (IsKeyDown(key)) {
                camera_direction += key_to_direction(key)
            }
        }
        camera_speed : f32 = IsKeyDown(KeyboardKey.LEFT_SHIFT) ? camera_fast_speed : camera_slow_speed
        camera.x += camera_direction.x * camera_speed * dt
        camera.y += camera_direction.y * camera_speed * dt
        
        if IsMouseButtonPressed(MouseButton.LEFT) {
            if mouse_pos := to_vec2_i32(GetMousePosition()); not_on_ui(mouse_pos) {
                pos := world_to_normalized(screen_to_world(mouse_pos, camera))
                color := player.active_color.? or_else ParticleColor(rand.int31_max(i32(particle_color_count)))
                for i := 0; i < int(player.click_spawn_count); i += 1 {
                    pos += {
                        particle_spawn_spread * rand.float32() - particle_spawn_spread / 2.0,
                        particle_spawn_spread * rand.float32() - particle_spawn_spread / 2.0
                    }
                    append(&particles, Particle{pos, {0, 0}, color})
                }
            }
        }
        
        // Debug Controls
        {
            if (IsKeyPressed(KeyboardKey.R)) {
                fill_with_random_values(&particle_attraction_table, -1.0, 1.0)
            }
            if (IsKeyPressed(KeyboardKey.C)) {
                clear(&particles)
            }
            if (IsKeyPressed(KeyboardKey.T)) {
                if _, ok := player.tracked_particle_index.?; ok {
                    player.tracked_particle_index = nil
                } else {
                    player.tracked_particle_index = 0   
                }
            }
            if (IsKeyPressed(KeyboardKey.F1)) {
                player.ui_disabled = !player.ui_disabled
            }
            if (IsKeyPressed(KeyboardKey.F11)) {
                resize_window_elements(GetMonitorWidth(0), GetMonitorHeight(0), &camera)
                ToggleBorderlessWindowed()
            }
            if (IsKeyPressed(KeyboardKey.SPACE)) {
                player.simulation_paused = !player.simulation_paused
            }
            if (IsKeyPressed(KeyboardKey.Z)) {
                for row := 0; row < particle_color_count; row += 1 {
                    for col := 0; col < particle_color_count; col += 1 {
                        particle_attraction_table[row][col] = 0.0
                    }
                }
            }
        }
               
        physics_begin := GetTime()
        if !player.simulation_paused {
            update_particles(particles, dt)
        }
        physics_time := GetTime() - physics_begin
        
        render_begin := GetTime()
        BeginDrawing()
        defer {
            EndDrawing()
            render_time = GetTime() - render_begin
        }

        ClearBackground(PINK)

        BeginTextureMode(target)
        {
            ClearBackground(viewport_bg)
            for p in particles {
                world_pos := normalized_to_world(p)
                DrawCircle(world_pos.x, world_pos.y, particle_radius, get_color(p.c))
            }
            
            if p_index, ok := player.tracked_particle_index.?; ok {
                p := particles[p_index]
                world_pos := normalized_to_world(p)
                world_pos_f := [2]f32{f32(world_pos.x), f32(world_pos.y)}
                DrawTextEx(font, TextFormat("(%02.2f, %02.2f)", p.x, p.y), world_pos_f - {0, 1.1 * particle_radius}, ui_font_size, 0.0, WHITE)
                p_direction := linalg.normalize(p.v)
                debug_direction_line_length :: 50.0
                end := world_pos_f + p_direction * debug_direction_line_length
                DrawLineV(world_pos_f, end, get_color(p.c))
                DrawTextEx(font, TextFormat("%02.2f", p.v), (world_pos_f + end) / 2.0 - {0, 1.1 * particle_radius}, ui_font_size, 0.0, WHITE)
            }
        }
        EndTextureMode()
        
        draw_texture_camera(target.texture, ui_panel_width, 0, camera)
        
        if !player.ui_disabled {
            DrawRectangle(0, 0, ui_panel_width, ui_panel_height, ui_panel_bg)
            
            ui_elements_pad :: 20
            ui_element_width :: ui_panel_width - 4 * ui_elements_pad
            pad :: 2
            y : f32 = 20.0
            DrawTextEx(font, TextFormat("Particle count: %d", len(particles)),       {ui_elements_pad, y + 0 * (ui_font_size + pad)}, ui_font_size, 0.0, WHITE)
            DrawTextEx(font, TextFormat("Frame:   %04.2fms (%d FPS)", 1000.0 * dt, i32(1.0 / dt)),           {ui_elements_pad, y + 1 * (ui_font_size + pad)}, ui_font_size, 0.0, WHITE)
            DrawTextEx(font, TextFormat("Physics: %04.2fms", 1000.0 * physics_time), {ui_elements_pad, y + 2 * (ui_font_size + pad)}, ui_font_size, 0.0, WHITE)
            DrawTextEx(font, TextFormat("Render:  %04.2fms", 1000.0 * render_time),  {ui_elements_pad, y + 3 * (ui_font_size + pad)}, ui_font_size, 0.0, WHITE)
            
            GuiSetFont(font)
            GuiSetStyle(i32(GuiControl.DEFAULT), i32(GuiDefaultProperty.TEXT_SIZE), ui_font_size)
            GuiSetStyle(i32(GuiControl.LABEL), i32(GuiTextWrapMode.TEXT_WRAP_CHAR), 1)
            {
                pun : u32 = 0xFFFFFFFF
                GuiSetStyle(i32(GuiControl.LABEL), i32(GuiControlProperty.TEXT_COLOR_NORMAL), transmute(i32)pun)
            }
            
            y = 120.0
            GuiLabel(Rectangle{ui_elements_pad, y, ui_panel_width, ui_element_height}, "Particle Radius")
            y += ui_element_height + ui_vertical_pad
            GuiSlider(Rectangle{ui_elements_pad, y, ui_element_width, ui_element_height}, "1.0", "10.0", &particle_radius, 1.0, 10.0)
            
            y += 2 * (ui_element_height + ui_vertical_pad)
            GuiLabel(Rectangle{ui_elements_pad, y, ui_panel_width, ui_element_height}, "Attraction Strength")
            y += ui_element_height + ui_vertical_pad
            GuiSlider(Rectangle{ui_elements_pad, y, ui_element_width, ui_element_height}, "0.0", "1.0", &particle_attraction_strength, 0.0, 1.0)
            
            y += 2 * (ui_element_height + ui_vertical_pad)
            GuiLabel(Rectangle{ui_elements_pad, y, ui_panel_width, ui_element_height}, "Max Distance")
            y += ui_element_height + ui_vertical_pad
            GuiSlider(Rectangle{ui_elements_pad, y, ui_element_width, ui_element_height}, "0.0", "1.0", &particle_max_distance, 0.0, 1.0)
            
            y += 2 * (ui_element_height + ui_vertical_pad)
            GuiLabel(Rectangle{ui_elements_pad, y, ui_panel_width, ui_element_height}, "Particle Repel Distance")
            y += ui_element_height + ui_vertical_pad
            GuiSlider(Rectangle{ui_elements_pad, y, ui_element_width, ui_element_height}, "0.0", "1.0", &particle_repel_distance, 0.0, 1.0)
                
            y += 2 * (ui_element_height + ui_vertical_pad)
            GuiLabel(Rectangle{ui_elements_pad, y, ui_panel_width, ui_element_height}, "Brush Strength")
            y += ui_element_height + ui_vertical_pad
            GuiSlider(Rectangle{ui_elements_pad, y, ui_element_width, ui_element_height}, "0", "15", &player.click_spawn_count, 0, 15.0)
          
            y += 2 * (ui_element_height + ui_vertical_pad)
            selected_color : i32 = 0
            if color, ok := player.active_color.?; ok {
                selected_color = i32(color) + 1
            }
            if GuiDropdownBox(Rectangle{ui_elements_pad, y, ui_element_width, 16}, "Select Color;RED;GREEN;BLUE;YELLOW;PURPLE;WHITE", &selected_color, false) {
                player.selecting_color = true
            }
            
            y += 40.0
            color_label_pad :: 6
            color_label_size :: 20
            color_label_offset :: color_label_size + color_label_pad
            
            color_rect := Rectangle{color_label_offset + ui_elements_pad, y, color_label_size, color_label_size}
            for col := 0; col < particle_color_count; col += 1 {
                DrawRectangleRec(color_rect, colors_table[col])
                color_rect.x += color_label_offset
            }
            y += color_label_offset
            color_rect = Rectangle{ui_elements_pad, y, color_label_size, color_label_size}
            for row := 0; row < particle_color_count; row += 1 {
                DrawRectangleRec(color_rect, colors_table[row])
                color_rect.y += color_label_offset
            }
            
            starting_x := ui_elements_pad + color_label_offset
            attraction_label_rect := Rectangle{
                f32(starting_x),
                y,
                color_label_size,
                color_label_size,
            }
            for row := 0; row < particle_color_count; row += 1 {
                for col := 0; col < particle_color_count; col += 1 {
                    color := lerp_color(RED, GREEN, (1.0 + particle_attraction_table[row][col]) / 2.0)
                    if player.adjusting_color == nil && GuiButton(attraction_label_rect, "") {
                        player.adjusting_color = [2]int{row, col}
                    }
                    DrawRectangleRec(attraction_label_rect, color)
                    attraction_label_rect.x += color_label_offset
                }
                attraction_label_rect.x = f32(starting_x)
                attraction_label_rect.y += color_label_offset
            }
            
            if player.selecting_color {
                color_button_y := y
                for row := 0; row < particle_color_count; row += 1 {
                    color_button_y += 22.0
                    color_button_rect := Rectangle{20.0, color_button_y, 20, 20}
                    
                    if GuiButton(color_button_rect, "") {
                        player.active_color = ParticleColor(row)
                        player.selecting_color = false
                    }
                    {
                        using color_button_rect
                        pad :: 4
                        DrawRectangleRec(Rectangle{x - pad, y - pad, width + 2 * pad, height + 2 * pad}, BLACK)
                    }
                    DrawRectangleRec(color_button_rect, colors_table[row])
                }
                color_button_y += 22.0
                rect := Rectangle{20.0, color_button_y, 20, 20}
                if GuiButton(rect, "") {
                    player.active_color = nil
                    player.selecting_color = false
                }
                DrawRectangleRec(rect, BLACK)
            }
            
            y += f32(particle_color_count) * color_label_offset
            
            if color_idx, is_adjusting := player.adjusting_color.?; is_adjusting {
                adjusted_value := &particle_attraction_table[color_idx.x][color_idx.y]
                GuiSlider(Rectangle{ui_elements_pad, y, ui_panel_width - 60.0, 16}, "-1.0", "1.0", adjusted_value, -1.0, 1.0)
                if GuiButton(Rectangle{ui_elements_pad + ui_panel_width - 55.0, y, 20, 20}, "X") {
                    player.adjusting_color = nil
                }
            }
        }
    }
}

adjust_camera :: proc(camera: ^MyCamera) {
    viewport_ratio := f32(viewport_height) / f32(viewport_width)
    camera.width  = f32(viewport_width) * camera.zoom
    camera.height = viewport_ratio * camera.width
}

resize_window_elements :: proc(new_width, new_height: i32, camera: ^MyCamera) {
    window_width = new_width
    window_height = new_height
    viewport_width = window_width
    viewport_height = window_height
    adjust_camera(camera)
}

to_vec2_i32 :: proc(p: [2]f32) -> [2]i32 {
    return {i32(p.x), i32(p.y)}
}

fill_with_random_values :: proc(mat: ^[6][6]f32, from: f32, to: f32) {
    for row := 0; row < 6; row += 1 {
        for col := 0; col < 6; col += 1 {
            mat[row][col] = (to - from) * rand.float32() + from
        }
    }
}

inside_viewport :: proc(p: [2]i32) -> bool {
    return 0 < p.x && p.x < i32(viewport_width) &&
           0 < p.y && p.y < i32(viewport_height)
}

rand_direction :: proc() -> [2]f32 {
    random_angle := 2 * math.PI * rand.float32()
    return [2]f32{math.cos(random_angle), math.sin(random_angle)}
}

get_color :: proc(pc: ParticleColor) -> rl.Color {
    return colors_table[int(pc)]
}

not_on_ui :: proc(p: [2]i32) -> bool {
    return !(0 < p.x && p.x < ui_panel_width &&
             0 < p.y && p.y < ui_panel_height)
}

draw_texture_camera :: proc(texture: rl.Texture, x, y: f32, camera: rl.Rectangle) {
    using rl
    flipped_texture_rect := Rectangle{camera.x, camera.y, f32(camera.width), -1.0 * f32(camera.height)}
    dest := Rectangle{0, 0, f32(window_width), f32(viewport_height)}
    DrawTexturePro(texture, flipped_texture_rect, dest, [2]f32{0, 0}, 0.0, WHITE)
}

check_leaks :: proc(tracking_allocator: ^mem.Tracking_Allocator) -> (has_leaks: bool) {
    if len(tracking_allocator.allocation_map) > 0 {
        fmt.eprintf("=== %v allocations not freed: ===\n", len(tracking_allocator.allocation_map))
        for _, entry in tracking_allocator.allocation_map {
            fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
        }
        has_leaks = true
    }
    if len(tracking_allocator.bad_free_array) > 0 {
        fmt.eprintf("=== %v incorrect frees: ===\n", len(tracking_allocator.bad_free_array))
        for entry in tracking_allocator.bad_free_array {
            fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
        }
        has_leaks = true
    }
    return has_leaks
}

lerp_u8 :: proc(a: u8, b: u8, t: f32) -> u8 {
    return u8(clamp(f32(a) + (f32(b) - f32(a)) * t, 0, 255))
}

lerp_color :: proc(c1: rl.Color, c2: rl.Color, t: f32) -> rl.Color {
    return rl.Color {
        lerp_u8(c1.r, c2.r, t),
        lerp_u8(c1.g, c2.g, t),
        lerp_u8(c1.b, c2.b, t),
        lerp_u8(c1.a, c2.a, t),
    }
}