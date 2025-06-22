const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const types = @import("types.zig");
const utils = @import("utils.zig");

// --- Input Event Types ---

pub const InputEvent = struct {
    pressed: bool,
    released: bool,
    position: rl.Vector2,
    source: enum { mouse, touch },
};

// --- Input Handling Functions ---

pub fn getInputEvent(state: *types.GameState) ?InputEvent {
    // Get current input states
    const mouse_pressed = rl.isMouseButtonDown(.left);
    const touch_count = rl.getTouchPointCount();
    const touch_active = touch_count > 0;

    // Check JavaScript touch state for more reliable touch detection on mobile
    const js_touch_active = if (builtin.target.os.tag == .emscripten) utils.js.get_input_active() else false;

    // On WASM/mobile, prioritize JavaScript touch detection over Raylib since Raylib can get stuck
    const effective_touch_active = if (builtin.target.os.tag == .emscripten)
        js_touch_active // Use ONLY JavaScript touch detection on WASM
    else
        touch_active or js_touch_active; // Use both on native

    var event: ?InputEvent = null;

    // Handle touch input first (prioritize touch over mouse)
    if (effective_touch_active and !state.last_touch_active) {
        // Touch started - use JavaScript coordinates (workaround for raylib-zig WASM issue)
        const js_x = if (builtin.target.os.tag == .emscripten) utils.js.get_input_x() else 0;
        const js_y = if (builtin.target.os.tag == .emscripten) utils.js.get_input_y() else 0;

        // Always use JavaScript coordinates for touch input if available
        const screen_size = utils.get_canvas_size();
        const actual_pos = if (js_x != 0 or js_y != 0)
            rl.Vector2{ .x = @as(f32, @floatFromInt(js_x)), .y = @as(f32, @floatFromInt(js_y)) }
        else if (touch_count > 0)
            rl.getTouchPosition(0) // Fallback to raylib touch position
        else
            rl.Vector2{ .x = @as(f32, @floatFromInt(@divTrunc(screen_size.w, 2))), .y = @as(f32, @floatFromInt(@divTrunc(screen_size.h, 2))) };

        event = InputEvent{
            .pressed = true,
            .released = false,
            .position = actual_pos,
            .source = .touch,
        };
    } else if (!effective_touch_active and state.last_touch_active) {
        // Touch ended - use last known JavaScript coordinates
        const js_x = if (builtin.target.os.tag == .emscripten) utils.js.get_input_x() else 0;
        const js_y = if (builtin.target.os.tag == .emscripten) utils.js.get_input_y() else 0;

        const end_pos = if (js_x != 0 or js_y != 0)
            rl.Vector2{ .x = @as(f32, @floatFromInt(js_x)), .y = @as(f32, @floatFromInt(js_y)) }
        else
            rl.getMousePosition(); // Fallback position

        event = InputEvent{
            .pressed = false,
            .released = true,
            .position = end_pos,
            .source = .touch,
        };
    }

    // If no touch input, handle mouse events
    if (event == null and !effective_touch_active) {
        if (mouse_pressed and !state.last_mouse_pressed) {
            // Mouse pressed
            event = InputEvent{
                .pressed = true,
                .released = false,
                .position = rl.getMousePosition(),
                .source = .mouse,
            };
        } else if (!mouse_pressed and state.last_mouse_pressed) {
            // Mouse released
            event = InputEvent{
                .pressed = false,
                .released = true,
                .position = rl.getMousePosition(),
                .source = .mouse,
            };
        }
    }

    // Update state tracking
    state.last_mouse_pressed = mouse_pressed;
    state.last_touch_active = effective_touch_active;

    return event;
}

pub fn handleTextInput(state: *types.GameState) void {
    if (state.game_state != .Submitting or !state.input_active) return;

    var key = rl.getCharPressed();
    while (key > 0) : (key = rl.getCharPressed()) {
        if (key >= 32 and key <= 126 and state.input_len < state.input_buffer.len - 1) {
            state.input_buffer[state.input_len] = @as(u8, @intCast(key));
            state.input_len += 1;
        }
    }
    if (rl.isKeyPressed(.backspace) and state.input_len > 0) {
        state.input_len -= 1;
    }
    state.input_buffer[state.input_len] = 0;
}
