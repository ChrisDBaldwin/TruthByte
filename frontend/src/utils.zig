const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const types = @import("types.zig");

// --- JavaScript Interop ---
/// Only declare these for WASM targets (e.g., wasm32-freestanding or emscripten)
pub const js = if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) struct {
    pub extern fn get_session_id() *const u8;
    pub extern fn get_session_id_len() usize;
    pub extern fn get_token() *const u8;
    pub extern fn get_token_len() usize;
    pub extern fn get_canvas_width() i32;
    pub extern fn get_canvas_height() i32;
    pub extern fn set_invited_shown(val: bool) void;
    pub extern fn get_input_x() i32;
    pub extern fn get_input_y() i32;
    pub extern fn get_input_active() bool;

    // Authentication functions
    pub fn init_auth(callback_ptr: *const fn (success: i32) callconv(.C) void) void {
        _ = callback_ptr;
    }
    pub fn auth_ping(callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void {
        _ = callback_ptr;
    }

    // API functions
    pub extern fn fetch_questions(num_questions: i32, tag_ptr: ?[*]const u8, tag_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;
    pub extern fn submit_answers(json_ptr: [*]const u8, json_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;
    pub extern fn propose_question(json_ptr: [*]const u8, json_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;

    pub export fn alloc(size: usize) *u8 {
        return @ptrCast(std.heap.page_allocator.alloc(u8, size) catch unreachable);
    }

    /// Local helper so rest of Zig can use slices
    pub fn get_session_id_slice() []const u8 {
        const ptr = get_session_id();
        const len = get_session_id_len();
        // Properly cast single pointer to many-item pointer
        return @as([*]const u8, @ptrCast(ptr))[0..len];
    }

    pub fn get_token_slice() []const u8 {
        const ptr = get_token();
        const len = get_token_len();
        // Properly cast single pointer to many-item pointer
        return @as([*]const u8, @ptrCast(ptr))[0..len];
    }
} else struct {
    // Provide stubs for native builds

    pub fn get_session_id() *const u8 {
        std.debug.print("get_session_id is not available in native build\n", .{});
        return "1234567890".ptr;
    }

    pub fn get_session_id_len() usize {
        std.debug.print("get_session_id_len is not available in native build\n", .{});
        return 10;
    }

    pub fn get_token() *const u8 {
        std.debug.print("get_token is not available in native build\n", .{});
        return "123".ptr;
    }

    pub fn get_token_len() usize {
        std.debug.print("get_token_len is not available in native build\n", .{});
        return 3;
    }

    pub fn set_invited_shown(val: bool) void {
        // no-op or panic
        _ = val;
        std.debug.print("set_invited_shown is not available in native build\n", .{});
    }

    pub fn get_canvas_width() i32 {
        return rl.getScreenWidth();
    }

    pub fn get_canvas_height() i32 {
        return rl.getScreenHeight();
    }

    pub fn get_input_x() i32 {
        return 0;
    }

    pub fn get_input_y() i32 {
        return 0;
    }

    pub fn get_input_active() bool {
        return false;
    }

    // Stub authentication functions for native builds
    pub fn init_auth(callback_ptr: *const fn (success: i32) callconv(.C) void) void {
        _ = callback_ptr;
        std.debug.print("init_auth is not available in native build\n", .{});
    }

    pub fn auth_ping(callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void {
        _ = callback_ptr;
        std.debug.print("auth_ping is not available in native build\n", .{});
    }

    // Stub API functions for native builds
    pub fn fetch_questions(num_questions: i32, tag_ptr: ?[*]const u8, tag_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void {
        _ = num_questions;
        _ = tag_ptr;
        _ = tag_len;
        _ = callback_ptr;
        std.debug.print("fetch_questions is not available in native build\n", .{});
    }

    pub fn submit_answers(json_ptr: [*]const u8, json_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void {
        _ = json_ptr;
        _ = json_len;
        _ = callback_ptr;
        std.debug.print("submit_answers is not available in native build\n", .{});
    }

    pub fn propose_question(json_ptr: [*]const u8, json_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void {
        _ = json_ptr;
        _ = json_len;
        _ = callback_ptr;
        std.debug.print("propose_question is not available in native build\n", .{});
    }

    /// Local helper so rest of Zig can use slices
    pub fn get_session_id_slice() []const u8 {
        const ptr = get_session_id();
        const len = get_session_id_len();
        // Properly cast single pointer to many-item pointer
        return @as([*]const u8, @ptrCast(ptr))[0..len];
    }

    pub fn get_token_slice() []const u8 {
        const ptr = get_token();
        const len = get_token_len();
        // Properly cast single pointer to many-item pointer
        return @as([*]const u8, @ptrCast(ptr))[0..len];
    }
};

// --- Color Utility Functions ---

pub fn hslToRgb(h: f32, s: f32, l: f32) rl.Color {
    const c = (1 - @abs(2 * l - 1)) * s;
    const x = c * (1 - @abs(@mod(h * 6, 2) - 1));
    const m = l - c / 2;
    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;
    if (h < 1.0 / 6.0) {
        r = c;
        g = x;
        b = 0;
    } else if (h < 2.0 / 6.0) {
        r = x;
        g = c;
        b = 0;
    } else if (h < 3.0 / 6.0) {
        r = 0;
        g = c;
        b = x;
    } else if (h < 4.0 / 6.0) {
        r = 0;
        g = x;
        b = c;
    } else if (h < 5.0 / 6.0) {
        r = x;
        g = 0;
        b = c;
    } else {
        r = c;
        g = 0;
        b = x;
    }
    return rl.Color{
        .r = @as(u8, @intFromFloat((r + m) * 255)),
        .g = @as(u8, @intFromFloat((g + m) * 255)),
        .b = @as(u8, @intFromFloat((b + m) * 255)),
        .a = 255,
    };
}

pub fn initPalettes(state: *types.GameState) void {
    var i: usize = 0;
    while (i < types.NUM_PALETTES) : (i += 1) {
        const bg_hue = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(types.NUM_PALETTES));
        const fg_hue = @mod(bg_hue + 0.5, 1.0);
        state.palettes[i] = types.Palette{
            .bg = hslToRgb(bg_hue, 0.5, 0.15),
            .fg = hslToRgb(fg_hue, 0.4, 0.85),
        };
    }
}

pub fn randomPalette(state: *types.GameState) types.Palette {
    const idx = state.prng.random().intRangeAtMost(usize, 0, types.NUM_PALETTES - 1);
    return state.palettes[idx];
}

// --- Canvas and Screen Utilities ---

pub fn get_canvas_size() struct { w: i32, h: i32 } {
    if (builtin.target.os.tag == .emscripten) {
        return .{ .w = js.get_canvas_width(), .h = js.get_canvas_height() };
    } else {
        return .{ .w = rl.getScreenWidth(), .h = rl.getScreenHeight() };
    }
}

// --- Game Logic Utilities ---

pub fn currentResponse(state: *types.GameState) *types.QuestionResponse {
    return &state.user_session.responses[state.session.current];
}

pub fn calcTrustScore(state: *types.GameState) f32 {
    return @as(f32, @floatFromInt(state.session.correct)) / 7.0;
}

pub fn showInviteModal() void {
    std.debug.print("Invite modal shown!\n", .{});
}
