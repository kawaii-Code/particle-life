package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:math"
import "core:math/rand"

import rl "vendor:raylib"

left  :: [2]f32{-1,  0}
right :: [2]f32{ 1,  0}
up    :: [2]f32{ 0, -1}
down  :: [2]f32{ 0,  1}

colors_table     : [color_count]rl.Color = { rl.RED, rl.GREEN, rl.BLUE, rl.YELLOW, rl.PURPLE, rl.WHITE }

window_width    :: 1000
window_height   :: 600

viewport_width  :: 800
viewport_height :: 600
viewport_bg     :: rl.Color{10, 10, 10, 255}

ui_width_ratio  :: 0.25
ui_area_width   :: window_width * ui_width_ratio
ui_area_height  :: window_height
ui_area_bg      :: rl.Color{40, 40, 40, 255}

font_size :: 16

camera_movement_keys : []rl.KeyboardKey : { .W, .A, .S, .D }
camera_slow_speed :: 500
camera_fast_speed :: 750
camera_zoom_speed :: 5
camera_min_zoom   :: 0.33
camera_max_zoom   :: 1.0




randomize_attraction_table :: proc() {
    for row := 0; row < color_count; row += 1 {
        for col := 0; col < color_count; col += 1 {
            attraction_table[row][col] = 2.0 * rand.float32() - 1.0
        }
    }
}

rand_direction :: proc() -> [2]f32 {
    random_angle := 2 * math.PI * rand.float32()
    return [2]f32{math.cos(random_angle), math.sin(random_angle)}
}

color_to_idx :: proc(pc: ParticleColor) -> int {
    return int(pc)
}

get_color :: proc(pc: ParticleColor) -> rl.Color {
    return colors_table[color_to_idx(pc)]
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

    target := LoadRenderTexture(viewport_width, viewport_height)
    font := LoadFontEx("CourierPrime.ttf", font_size, nil, 0)
    
    camera : Camera2D
    camera.zoom = 1.0
    camera.target = [2]f32{window_width, window_height} / 2
    camera.offset = [2]f32{window_width, window_height} / 2

    particles : [dynamic]Particle
    defer delete(particles)
    randomize_attraction_table()

    active_color : Maybe(ParticleColor) = nil
    adjusting_color : Maybe([2]int)
    selecting := false

    render_time := 0.0
    for !WindowShouldClose() {
        dt := GetFrameTime()
        
        camera.zoom += camera_zoom_speed * GetMouseWheelMove() * dt
        camera.zoom = clamp(camera.zoom, camera_min_zoom, camera_max_zoom)
        key_to_direction :: proc(key: KeyboardKey) -> [2]f32 {
            #partial switch (key) {
                case .W: return up
                case .A: return left
                case .S: return down
                case .D: return right
                case: assert(false)
            }
            return [2]f32{0, 0}
        }
        camera_direction := [2]f32{0, 0}
        for key in camera_movement_keys {
            if (IsKeyDown(key)) {
                camera_direction += key_to_direction(key)
            }
        }
        camera_speed : f32 = IsKeyDown(KeyboardKey.LEFT_SHIFT) ? camera_fast_speed : camera_slow_speed
        camera.offset -= camera_direction * camera_speed * dt
        wrap_camera(&camera)
        
        if IsMouseButtonPressed(MouseButton.LEFT) && inside_viewport(GetMousePosition()) {
            pos := viewport_to_normalized(screen_to_viewport(GetScreenToWorld2D(GetMousePosition(), camera)))
            color := active_color.? or_else rand.choice_enum(ParticleColor)
            for i := 0; i < 5; i += 1 {
                pos += [2]f32{particle_spread*rand.float32() - particle_spread / 2.0, particle_spread*rand.float32() - particle_spread / 2.0}
                append(&particles, Particle{pos, {0, 0}, color})                
            }
        }
        
        if (IsKeyPressed(KeyboardKey.R)) {
            randomize_attraction_table()
        }
        
        if (IsKeyPressed(KeyboardKey.C)) {
            clear(&particles)
        }
    
        physics_begin := GetTime()
        update_particles(particles, dt)
        physics_time := GetTime() - physics_begin
    
        render_begin := GetTime()
        BeginDrawing()
        defer EndDrawing()

        ClearBackground(PINK)

        BeginTextureMode(target)
        {
            ClearBackground(viewport_bg)
            for p in particles {
                screen_pos := normalized_to_viewport(p)
                DrawCircle(screen_pos.x, screen_pos.y, particle_radius, get_color(p.c))
            }        
        }
        EndTextureMode()        
        BeginMode2D(camera)
        for row : i32 = -1; row <= 1; row += 1 {
            for col : i32 = -1; col <= 1; col += 1 {
                x := target.texture.width * col
                y := target.texture.height * row
                draw_texture_flipped(target.texture, f32(x), f32(y))
            }
        }
        EndMode2D()
        
        
        DrawRectangle(0, 0, ui_area_width, ui_area_height, ui_area_bg)

        ui_elements_pad :: 20
        ui_element_width :: ui_area_width - 4 * ui_elements_pad
        pad :: 2
        y : f32 = 20.0
        DrawTextEx(font, TextFormat("Particle count: %d", len(particles)),       [2]f32{ui_elements_pad, y + 0 * (font_size + pad)}, font_size, 0.0, WHITE)
        DrawTextEx(font, TextFormat("Frame:   %04.2fms", 1000.0 * dt),           [2]f32{ui_elements_pad, y + 1 * (font_size + pad)}, font_size, 0.0, WHITE)
        DrawTextEx(font, TextFormat("Physics: %04.2fms", 1000.0 * physics_time), [2]f32{ui_elements_pad, y + 2 * (font_size + pad)}, font_size, 0.0, WHITE)
        DrawTextEx(font, TextFormat("Render:  %04.2fms", 1000.0 * render_time),  [2]f32{ui_elements_pad, y + 3 * (font_size + pad)}, font_size, 0.0, WHITE)

        GuiSetFont(font)
        GuiSetStyle(i32(GuiControl.DEFAULT), i32(GuiDefaultProperty.TEXT_SIZE), font_size)
        GuiSetStyle(i32(GuiControl.LABEL), i32(GuiTextWrapMode.TEXT_WRAP_CHAR), 1)
        {
            pun : u32 = 0xFFFFFFFF
            GuiSetStyle(i32(GuiControl.LABEL), i32(GuiControlProperty.TEXT_COLOR_NORMAL), transmute(i32)pun)
        }

        y = 120.0
        GuiLabel(Rectangle{ui_elements_pad, y, ui_area_width, 16}, "Particle Radius")
        y += 20.0
        GuiSlider(Rectangle{ui_elements_pad, y, ui_element_width, 16}, "1.0", "10.0", &particle_radius, 1.0, 10.0)
        
        y += 40.0
        GuiLabel(Rectangle{ui_elements_pad, y, ui_area_width, 16}, "Attraction Strength")
        y += 20.0
        GuiSlider(Rectangle{ui_elements_pad, y, ui_element_width, 16}, "0.0", "5.0", &particle_attraction_strength, 0.0, 5.0)

        y += 40.0
        GuiLabel(Rectangle{ui_elements_pad, y, ui_area_width, 16}, "Max Distance")
        y += 20.0
        GuiSlider(Rectangle{ui_elements_pad, y, ui_element_width, 16}, "0.0", "1.0", &particle_max_distance, 0.0, 1.0)
        
        y += 40.0
        GuiLabel(Rectangle{ui_elements_pad, y, ui_area_width, 16}, "Particle Repel Distance")
        y += 20.0
        GuiSlider(Rectangle{ui_elements_pad, y, ui_element_width, 16}, "0.0", "1.0", &particle_repel_distance, 0.0, 1.0)
        
        y += 40.0
        selected_color : i32 = 0
        if color, ok := active_color.?; ok {
            selected_color = i32(color_to_idx(color)) + 1
        }
        if GuiDropdownBox(Rectangle{ui_elements_pad, y, ui_element_width, 16}, "Select Color;RED;GREEN;BLUE;YELLOW;PURPLE;WHITE", &selected_color, false) {
            selecting = true
        } 
        
        y += 40.0
        color_label_pad :: 6
        color_label_size :: 20
        color_label_offset :: color_label_size + color_label_pad
    
        color_rect := Rectangle{color_label_offset + ui_elements_pad, y, color_label_size, color_label_size}
        for col := 0; col < color_count; col += 1 {
            DrawRectangleRec(color_rect, colors_table[col])
            color_rect.x += color_label_offset
        }
        y += color_label_offset
        color_rect = Rectangle{ui_elements_pad, y, color_label_size, color_label_size}
        for row := 0; row < color_count; row += 1 {
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
        for row := 0; row < color_count; row += 1 {
            for col := 0; col < color_count; col += 1 {
                color := lerp_color(RED, GREEN, (1.0 + attraction_table[row][col]) / 2.0)
                if adjusting_color == nil && GuiButton(attraction_label_rect, "") {
                    adjusting_color = [2]int{row, col}
                }
                DrawRectangleRec(attraction_label_rect, color)
                attraction_label_rect.x += color_label_offset
            }
            attraction_label_rect.x = f32(starting_x)
            attraction_label_rect.y += color_label_offset
        }
        
        if selecting {
            color_button_y := y
            for row := 0; row < color_count; row += 1 {
                color_button_y += 22.0
                color_button_rect := Rectangle{20.0, color_button_y, 20, 20}
                
                if GuiButton(color_button_rect, "") {
                    active_color = ParticleColor(row)
                    selecting = false
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
                active_color = nil
                selecting = false
            }
            DrawRectangleRec(rect, BLACK)
        }
        
        y += color_count * color_label_offset
        
        if color_idx, is_adjusting := adjusting_color.?; is_adjusting {
            adjusted_value := &attraction_table[color_idx.x][color_idx.y]
            GuiSlider(Rectangle{ui_elements_pad, y, ui_area_width - 60.0, 16}, "-1.0", "1.0", adjusted_value, -1.0, 1.0)
            
            if GuiButton(Rectangle{ui_elements_pad + ui_area_width - 55.0, y, 20, 20}, "X") {
                adjusting_color = nil
            }
        }

        render_time = GetTime() - render_begin
    }
}

wrap_camera :: proc(camera: ^rl.Camera2D) {
    using camera
    
    if offset.x < -viewport_width / 2.0 {
        offset.x += viewport_width
    } else if offset.x > 1.5 * viewport_width {
        offset.x -= viewport_width
    }
    if offset.y < -viewport_height / 2.0 {
        offset.y += viewport_height
    } else if offset.y > 1.5 * viewport_height {
        offset.y -= viewport_height
    }
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

draw_texture_flipped :: proc(texture: rl.Texture, x, y: f32) {
    using rl
    flipped_texture_rect := Rectangle{0, 0, f32(texture.width), -1.0 * f32(texture.height)}
    DrawTextureRec(texture, flipped_texture_rect, [2]f32{x, y}, WHITE)
}

inside_viewport :: proc(p: [2]f32) -> bool {
    return p.x > ui_area_width
}

screen_to_viewport :: proc(p: [2]f32) -> [2]i32 {
    return [2]i32{i32(p.x), i32(p.y)}
}

viewport_to_normalized :: proc(p: [2]i32) -> [2]f32 {
    x := f32(p.x) / f32(viewport_width)
    y := f32(p.y) / f32(viewport_height)
    return [2]f32{x, y}
}

normalized_to_viewport :: proc(p: [2]f32) -> [2]i32 {
    x := i32(p.x * viewport_width)
    y := i32(p.y * viewport_height)
    return [2]i32{x, y}
}

viewport_to_screen :: proc(p: [2]i32) -> [2]i32 {
    return [2]i32{p.x + ui_area_width, p.y}
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