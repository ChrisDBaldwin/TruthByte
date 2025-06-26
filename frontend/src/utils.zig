const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const types = @import("types.zig");
const render = @import("render.zig");

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
    pub extern fn init_auth(callback_ptr: *const fn (success: i32) callconv(.C) void) void;
    pub extern fn auth_ping(callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;

    // API functions
    pub extern fn fetch_questions(num_questions: i32, tag_ptr: ?[*]const u8, tag_len: usize, user_id_ptr: [*]const u8, user_id_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;
    pub extern fn fetch_questions_enhanced(num_questions: i32, category_ptr: ?[*]const u8, category_len: usize, difficulty: u8, user_id_ptr: [*]const u8, user_id_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;
    pub extern fn fetch_categories(user_id_ptr: [*]const u8, user_id_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;
    pub extern fn submit_answers(json_ptr: [*]const u8, json_len: usize, user_id_ptr: [*]const u8, user_id_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;
    pub extern fn propose_question(json_ptr: [*]const u8, json_len: usize, user_id_ptr: [*]const u8, user_id_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;
    pub extern fn fetch_user(user_id_ptr: [*]const u8, user_id_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;

    // --- Text Input Functions ---
    pub extern fn showTextInput(x: i32, y: i32, width: i32, height: i32, placeholder_ptr: ?[*]const u8, placeholder_len: usize) bool;
    pub extern fn hideTextInput() bool;
    pub extern fn getTextInputValue() ?*u8;
    pub extern fn getTextInputValueLength() usize;
    pub extern fn isTextInputFocused() bool;
    pub extern fn clearTextInput() bool;
    pub extern fn setTextInputValue(value_ptr: [*]const u8, value_len: usize) bool;
    // Legacy compatibility
    pub extern fn createTextInput(x: i32, y: i32, width: i32, height: i32, placeholder_ptr: ?[*]const u8, placeholder_len: usize) bool;
    pub extern fn activate_mobile_keyboard() bool;

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

    /// Helper function to show text input with string placeholder
    pub fn showTextInputWithString(x: i32, y: i32, width: i32, height: i32, placeholder: []const u8) bool {
        return showTextInput(x, y, width, height, placeholder.ptr, placeholder.len);
    }

    /// Legacy helper function for compatibility
    pub fn createTextInputWithString(x: i32, y: i32, width: i32, height: i32, placeholder: []const u8) bool {
        return showTextInput(x, y, width, height, placeholder.ptr, placeholder.len);
    }

    /// Helper function to get text input value as Zig string
    pub fn getTextInputValueSlice() []const u8 {
        const ptr = getTextInputValue();
        if (ptr == null) return "";
        const len = getTextInputValueLength();
        if (len == 0) return "";
        return @as([*]const u8, @ptrCast(ptr.?))[0..len];
    }

    /// Helper function to set text input value from Zig string
    pub fn setTextInputValueFromString(value: []const u8) bool {
        return setTextInputValue(value.ptr, value.len);
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
    pub fn fetch_questions(num_questions: i32, tag_ptr: ?[*]const u8, tag_len: usize, user_id_ptr: [*]const u8, user_id_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void {
        _ = num_questions;
        _ = tag_ptr;
        _ = tag_len;
        _ = user_id_ptr;
        _ = user_id_len;
        _ = callback_ptr;
        std.debug.print("fetch_questions is not available in native build\n", .{});
    }

    pub fn fetch_questions_enhanced(num_questions: i32, category_ptr: ?[*]const u8, category_len: usize, difficulty: u8, user_id_ptr: [*]const u8, user_id_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void {
        _ = num_questions;
        _ = category_ptr;
        _ = category_len;
        _ = difficulty;
        _ = user_id_ptr;
        _ = user_id_len;
        _ = callback_ptr;
        std.debug.print("fetch_questions_enhanced is not available in native build\n", .{});
    }

    pub fn fetch_categories(user_id_ptr: [*]const u8, user_id_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void {
        _ = user_id_ptr;
        _ = user_id_len;
        _ = callback_ptr;
        std.debug.print("fetch_categories is not available in native build\n", .{});
    }

    pub fn submit_answers(json_ptr: [*]const u8, json_len: usize, user_id_ptr: [*]const u8, user_id_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void {
        _ = json_ptr;
        _ = json_len;
        _ = user_id_ptr;
        _ = user_id_len;
        _ = callback_ptr;
        std.debug.print("submit_answers is not available in native build\n", .{});
    }

    pub fn propose_question(json_ptr: [*]const u8, json_len: usize, user_id_ptr: [*]const u8, user_id_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void {
        _ = json_ptr;
        _ = json_len;
        _ = user_id_ptr;
        _ = user_id_len;
        _ = callback_ptr;
        std.debug.print("propose_question is not available in native build\n", .{});
    }

    pub fn fetch_user(user_id_ptr: [*]const u8, user_id_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void {
        _ = user_id_ptr;
        _ = user_id_len;
        _ = callback_ptr;
        std.debug.print("fetch_user is not available in native build\n", .{});
    }

    // --- Text Input Functions (Native Stubs) ---
    pub fn showTextInput(x: i32, y: i32, width: i32, height: i32, placeholder_ptr: ?[*]const u8, placeholder_len: usize) bool {
        _ = x;
        _ = y;
        _ = width;
        _ = height;
        _ = placeholder_ptr;
        _ = placeholder_len;
        std.debug.print("showTextInput is not available in native build\n", .{});
        return false;
    }

    pub fn hideTextInput() bool {
        std.debug.print("hideTextInput is not available in native build\n", .{});
        return false;
    }

    pub fn getTextInputValue() ?*u8 {
        std.debug.print("getTextInputValue is not available in native build\n", .{});
        return null;
    }

    pub fn getTextInputValueLength() usize {
        std.debug.print("getTextInputValueLength is not available in native build\n", .{});
        return 0;
    }

    pub fn isTextInputFocused() bool {
        std.debug.print("isTextInputFocused is not available in native build\n", .{});
        return false;
    }

    pub fn clearTextInput() bool {
        std.debug.print("clearTextInput is not available in native build\n", .{});
        return false;
    }

    pub fn setTextInputValue(value_ptr: [*]const u8, value_len: usize) bool {
        _ = value_ptr;
        _ = value_len;
        std.debug.print("setTextInputValue is not available in native build\n", .{});
        return false;
    }

    // Legacy compatibility
    pub fn createTextInput(x: i32, y: i32, width: i32, height: i32, placeholder_ptr: ?[*]const u8, placeholder_len: usize) bool {
        return showTextInput(x, y, width, height, placeholder_ptr, placeholder_len);
    }

    pub fn activate_mobile_keyboard() bool {
        std.debug.print("activate_mobile_keyboard is not available in native build\n", .{});
        return false;
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

    /// Helper function to show text input with string placeholder
    pub fn showTextInputWithString(x: i32, y: i32, width: i32, height: i32, placeholder: []const u8) bool {
        return showTextInput(x, y, width, height, placeholder.ptr, placeholder.len);
    }

    /// Legacy helper function for compatibility
    pub fn createTextInputWithString(x: i32, y: i32, width: i32, height: i32, placeholder: []const u8) bool {
        return showTextInput(x, y, width, height, placeholder.ptr, placeholder.len);
    }

    /// Helper function to get text input value as Zig string
    pub fn getTextInputValueSlice() []const u8 {
        const ptr = getTextInputValue();
        if (ptr == null) return "";
        const len = getTextInputValueLength();
        if (len == 0) return "";
        return @as([*]const u8, @ptrCast(ptr.?))[0..len];
    }

    /// Helper function to set text input value from Zig string
    pub fn setTextInputValueFromString(value: []const u8) bool {
        return setTextInputValue(value.ptr, value.len);
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

pub fn get_canvas_size() render.CanvasSize {
    // Handle comptime calls by providing reasonable defaults
    if (@inComptime()) {
        return .{ .w = 800, .h = 600 }; // Default size for comptime evaluation
    }

    if (builtin.target.os.tag == .emscripten) {
        return .{ .w = js.get_canvas_width(), .h = js.get_canvas_height() };
    } else {
        return .{ .w = rl.getScreenWidth(), .h = rl.getScreenHeight() };
    }
}

/// Forces raylib to update its internal canvas size to match the browser canvas
/// This should be called every frame to ensure layout is responsive to canvas changes
pub fn updateCanvasSize() void {
    if (builtin.target.os.tag == .emscripten) {
        const new_width = js.get_canvas_width();
        const new_height = js.get_canvas_height();

        // Only update if dimensions actually changed to avoid unnecessary operations
        if (rl.getScreenWidth() != new_width or rl.getScreenHeight() != new_height) {
            rl.setWindowSize(new_width, new_height);
        }
    }
}

// --- Game Logic Utilities ---

pub fn currentResponse(state: *types.GameState) *types.QuestionResponse {
    return &state.user_session.responses[state.session.current];
}

pub fn calcTrustScore(state: *types.GameState) f32 {
    return @as(f32, @floatFromInt(state.session.correct)) / 7.0;
}

pub fn showInviteModal() void {}
