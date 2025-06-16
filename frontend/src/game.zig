const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");

// --- Layout Constants ---
const MARGIN = 24;
const LARGE_FONT_SIZE = 32;
const MEDIUM_FONT_SIZE = 24;
const SMALL_FONT_SIZE = 20;
const ELEMENT_SPACING = 40;
const SMALL_SPACING = 20;
const MEDIUM_SPACING = 60;
const TEXT_PADDING = 10;
const BUTTON_TEXT_OFFSET_X = 60;
const BUTTON_TEXT_OFFSET_Y = 25;
const CONFIRM_TEXT_OFFSET_X = 40;
const CONFIRM_TEXT_OFFSET_Y = 18;
const THICK_BORDER = 8;
const THIN_BORDER = 4;
const INPUT_BORDER = 2;
const CURSOR_WIDTH = 10;
const CURSOR_HEIGHT = 20;

// --- UI Element Dimensions ---
const COLOR_BUTTON_WIDTH = 80;
const COLOR_BUTTON_HEIGHT = 40;
const BOTTOM_BUTTON_WIDTH = 90;
const BOTTOM_BUTTON_HEIGHT = 40;
const BOTTOM_BUTTON_GAP = 20;
const INPUT_BOX_WIDTH = 400;
const INPUT_BOX_HEIGHT = 40;
const BUTTON_GAP = 40;

// --- Types and constants from main.zig ---

const Palette = struct {
    bg: rl.Color,
    fg: rl.Color,
};

const accent = rl.Color{ .r = 255, .g = 99, .b = 71, .a = 255 }; // tomato (stark)
const button_w = 240;
const button_h = 80;
const button_y = 220;
const button_gap = 60;
const confirm_w = 200;
const confirm_h = 60;
const confirm_y = button_y + button_h + button_gap + 30;
const NUM_PALETTES = 100;

const QuestionResponse = struct {
    question_id: []const u8,
    answer: ?bool = null,
    start_time: i64 = 0,
    duration: f64 = 0.0,
};

const UserSessionResponse = struct {
    session_id: []const u8 = "",
    token: []const u8 = "",
    trust: f32 = 0.0,
    invitable: bool = false,
    responses: [10]QuestionResponse,
    timestamp: i64,
};

const GameStateEnum = enum { Loading, Answering, Submitting, Finished };

const Question = struct {
    id: [:0]const u8, // Unique identifier
    tags: []const []const u8 = &.{}, // Tags/categories
    question: [:0]const u8, // The main question text
    title: [:0]const u8 = "", // Short label/headline (optional)
    passage: [:0]const u8 = "", // Supporting passage (optional)
    answer: bool, // True/False answer
};

const Session = struct {
    questions: [10]Question,
    current: usize = 0,
    correct: usize = 0,
    finished: bool = false,
};

const question_pool = [_]Question{
    Question{ .id = "q001", .tags = &.{ "food", "meme" }, .question = "Pizza is a vegetable?", .title = "Pizza Fact", .passage = "Some US lawmakers once argued that pizza counts as a vegetable in school lunches.", .answer = false },
    Question{ .id = "q002", .tags = &.{ "science", "nature" }, .question = "The sky is blue?", .title = "Sky Color", .passage = "", .answer = true },
    Question{ .id = "q003", .tags = &.{"math"}, .question = "2+2=5?", .title = "Math Check", .passage = "", .answer = false },
    Question{ .id = "q004", .tags = &.{ "science", "physics" }, .question = "Water boils at 100C?", .title = "Boiling Point", .passage = "", .answer = true },
    Question{ .id = "q005", .tags = &.{ "animals", "meme" }, .question = "Cats can fly?", .title = "Cat Fact", .passage = "", .answer = false },
    Question{ .id = "q006", .tags = &.{ "science", "geography" }, .question = "Earth is round?", .title = "Earth Shape", .passage = "", .answer = true },
    Question{ .id = "q007", .tags = &.{"science"}, .question = "Fire is cold?", .title = "Fire Fact", .passage = "", .answer = false },
    Question{ .id = "q008", .tags = &.{"animals"}, .question = "Fish can swim?", .title = "Fish Fact", .passage = "", .answer = true },
    Question{ .id = "q009", .tags = &.{ "animals", "biology" }, .question = "Birds are mammals?", .title = "Bird Fact", .passage = "", .answer = false },
    Question{ .id = "q010", .tags = &.{ "science", "geography" }, .question = "Sun rises in the east?", .title = "Sunrise", .passage = "", .answer = true },
};

pub const GameState = struct {
    // Palette and color state
    palettes: [NUM_PALETTES]Palette = undefined,
    bg_color: rl.Color = rl.Color{ .r = 200, .g = 215, .b = 235, .a = 255 },
    fg_color: rl.Color = rl.Color{ .r = 255, .g = 245, .b = 230, .a = 255 },
    // Game/session state
    game_state: GameStateEnum = .Loading,
    session: Session = undefined,
    user_session: UserSessionResponse = UserSessionResponse{
        .responses = undefined,
        .timestamp = 0,
    },
    user_trust: f32 = 0.0,
    invited_shown: bool = false,
    // UI state
    input_active: bool = false,
    input_buffer: [256]u8 = undefined,
    input_len: usize = 0,
    // Per-question state
    response: QuestionResponse = QuestionResponse{ .question_id = "q001", .answer = null },
    selected: ?bool = null,
    // Input state tracking
    last_mouse_pressed: bool = false,
    last_touch_active: bool = false,
    // Loading state
    loading_message: [:0]const u8 = "Loading questions...",
    // PRNG
    prng: std.Random.DefaultPrng = undefined,
    last_screen_width: i32 = 0,
    last_screen_height: i32 = 0,
};

// Global state pointer for callbacks (needed because callbacks can't capture context)
var g_state: ?*GameState = null;

// --- Input handling functions ---
pub const InputEvent = struct {
    pressed: bool,
    released: bool,
    position: rl.Vector2,
    source: enum { mouse, touch },
};

fn getInputEvent(state: *GameState) ?InputEvent {
    // Get current input states
    const mouse_pressed = rl.isMouseButtonDown(.left);
    const touch_count = rl.getTouchPointCount();
    const touch_active = touch_count > 0;

    var event: ?InputEvent = null;

    // Handle touch input first (prioritize touch over mouse)
    if (touch_active and !state.last_touch_active) {
        // Touch started - use JavaScript coordinates (workaround for raylib-zig WASM issue)
        const js_x = if (builtin.target.os.tag == .emscripten) js.get_input_x() else 0;
        const js_y = if (builtin.target.os.tag == .emscripten) js.get_input_y() else 0;

        // Use JavaScript coordinates if available, otherwise fallback to center of screen
        const screen_size = get_canvas_size();
        const actual_pos = if (js_x > 0 or js_y > 0)
            rl.Vector2{ .x = @as(f32, @floatFromInt(js_x)), .y = @as(f32, @floatFromInt(js_y)) }
        else
            rl.Vector2{ .x = @as(f32, @floatFromInt(@divTrunc(screen_size.w, 2))), .y = @as(f32, @floatFromInt(@divTrunc(screen_size.h, 2))) };

        event = InputEvent{
            .pressed = true,
            .released = false,
            .position = actual_pos,
            .source = .touch,
        };
    } else if (!touch_active and state.last_touch_active) {
        // Touch ended - use last known mouse position as fallback
        // (we can't get touch position after touch ends)
        event = InputEvent{
            .pressed = false,
            .released = true,
            .position = rl.getMousePosition(), // Fallback position
            .source = .touch,
        };
    }

    // If no touch input, handle mouse events
    if (event == null and !touch_active) {
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
    state.last_touch_active = touch_active;

    return event;
}

// --- Helper functions and JS interop ---
/// Only declare these for WASM targets (e.g., wasm32-freestanding or emscripten)
pub const js = if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) struct {
    extern fn get_session_id() *const u8;
    extern fn get_session_id_len() usize;
    extern fn get_token() *const u8;
    extern fn get_token_len() usize;
    extern fn get_canvas_width() i32;
    extern fn get_canvas_height() i32;
    extern fn set_invited_shown(val: bool) void;
    extern fn get_input_x() i32;
    extern fn get_input_y() i32;
    extern fn get_input_active() bool;

    // API functions
    extern fn fetch_questions(num_questions: i32, tag_ptr: ?[*]const u8, tag_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;
    extern fn submit_answers(json_ptr: [*]const u8, json_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;
    extern fn propose_question(json_ptr: [*]const u8, json_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;

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

fn hslToRgb(h: f32, s: f32, l: f32) rl.Color {
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

fn initPalettes(state: *GameState) void {
    var i: usize = 0;
    while (i < NUM_PALETTES) : (i += 1) {
        const bg_hue = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(NUM_PALETTES));
        const fg_hue = @mod(bg_hue + 0.5, 1.0);
        state.palettes[i] = Palette{
            .bg = hslToRgb(bg_hue, 0.5, 0.15),
            .fg = hslToRgb(fg_hue, 0.4, 0.85),
        };
    }
}

fn randomPalette(state: *GameState) Palette {
    const idx = state.prng.random().intRangeAtMost(usize, 0, NUM_PALETTES - 1);
    return state.palettes[idx];
}

fn startSession(state: *GameState) void {
    state.game_state = .Loading;
    state.loading_message = "Loading questions...";

    // Set global state for callback
    g_state = state;

    // Call fetch_questions API
    if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) {
        js.fetch_questions(10, null, 0, on_questions_received);
    } else {
        // For native builds, use fallback immediately
        initSessionWithFallback(state);
    }
}

fn currentResponse(state: *GameState) *QuestionResponse {
    return &state.user_session.responses[state.session.current];
}

fn calcTrustScore(state: *GameState) f32 {
    return @as(f32, @floatFromInt(state.session.correct)) / 10.0;
}

fn showInviteModal() void {
    std.debug.print("Invite modal shown!\n", .{});
}

fn submitResponseBatch(user_session_response: *UserSessionResponse) void {
    user_session_response.session_id = js.get_session_id_slice();
    user_session_response.token = js.get_token_slice();
    user_session_response.trust = user_session_response.trust;
    user_session_response.invitable = false; // TODO: implement
    user_session_response.responses = user_session_response.responses;
    user_session_response.timestamp = std.time.timestamp();

    std.debug.print("Submitting session: session_id: {s}\n token: {s}\n timestamp: {d}\n responses: {any}\n trust: {d}\n invitable: {}\n", .{
        user_session_response.session_id,
        user_session_response.token,
        user_session_response.timestamp,
        user_session_response.responses,
        user_session_response.trust,
        user_session_response.invitable,
    });
}

pub fn get_canvas_size() struct { w: i32, h: i32 } {
    if (builtin.target.os.tag == .emscripten) {
        return .{ .w = js.get_canvas_width(), .h = js.get_canvas_height() };
    } else {
        return .{ .w = rl.getScreenWidth(), .h = rl.getScreenHeight() };
    }
}

// --- Exported API ---

pub export fn init(allocator: *std.mem.Allocator) callconv(.C) *anyopaque {
    const state = allocator.create(GameState) catch unreachable;
    initPalettes(state);
    state.prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));
    const pal = randomPalette(state);
    state.bg_color = pal.bg;
    state.fg_color = pal.fg;

    // Set global state pointer for callbacks
    g_state = state;

    startSession(state);
    state.input_active = false;
    state.input_len = 0;
    state.input_buffer[0] = 0;
    state.response = QuestionResponse{ .question_id = "q001", .answer = null };
    state.selected = null;
    // Ensure proper alignment when returning
    return @ptrCast(@alignCast(state));
}

pub export fn deinit(allocator: *std.mem.Allocator, state: *GameState) callconv(.C) void {
    allocator.destroy(state);
}

pub export fn update(state: *GameState) callconv(.C) void {
    const raylib = rl;
    const size = get_canvas_size();
    const screen_width = size.w;
    const screen_height = size.h;

    // Update Raylib's render size if the canvas size changed
    if (state.last_screen_width != screen_width or state.last_screen_height != screen_height) {
        raylib.setWindowSize(screen_width, screen_height);
        state.last_screen_width = screen_width;
        state.last_screen_height = screen_height;
    }

    // Calculate vertical center and spacing for main UI
    const ui_block_height = MEDIUM_FONT_SIZE + SMALL_SPACING + LARGE_FONT_SIZE + ELEMENT_SPACING + button_h + ELEMENT_SPACING + confirm_h; // Total height of UI elements
    const ui_start_y = @divTrunc((screen_height - ui_block_height), 2);
    const progress_y = ui_start_y;
    const question_y = progress_y + MEDIUM_FONT_SIZE + SMALL_SPACING;
    const buttons_y = question_y + LARGE_FONT_SIZE + ELEMENT_SPACING;
    const confirm_button_y = buttons_y + button_h + ELEMENT_SPACING;

    // Calculate positions (same as in draw function)
    const total_button_width = button_w * 2 + BUTTON_GAP;
    const buttons_x = @as(f32, @floatFromInt(@divTrunc((screen_width - total_button_width), 2)));
    const button_rect_true = raylib.Rectangle{ .x = buttons_x, .y = @as(f32, @floatFromInt(buttons_y)), .width = button_w, .height = button_h };
    const button_rect_false = raylib.Rectangle{ .x = buttons_x + button_w + BUTTON_GAP, .y = @as(f32, @floatFromInt(buttons_y)), .width = button_w, .height = button_h };
    const confirm_x = @as(f32, @floatFromInt(@divTrunc((screen_width - confirm_w), 2)));
    const confirm_rect = raylib.Rectangle{ .x = confirm_x, .y = @as(f32, @floatFromInt(confirm_button_y)), .width = confirm_w, .height = confirm_h };

    // COLOR button in top right
    const randomize_btn_x = @as(f32, @floatFromInt(screen_width - COLOR_BUTTON_WIDTH - MARGIN));
    const randomize_btn_y = @as(f32, @floatFromInt(MARGIN));
    const randomize_btn = raylib.Rectangle{ .x = randomize_btn_x, .y = randomize_btn_y, .width = COLOR_BUTTON_WIDTH, .height = COLOR_BUTTON_HEIGHT };

    // SUBMIT and ANSWER buttons in bottom right
    const bottom_btn_y = @as(f32, @floatFromInt(screen_height - BOTTOM_BUTTON_HEIGHT - MARGIN));
    const answer_btn_x = @as(f32, @floatFromInt(screen_width - BOTTOM_BUTTON_WIDTH - MARGIN));
    const submit_btn_x = answer_btn_x - BOTTOM_BUTTON_WIDTH - BOTTOM_BUTTON_GAP;
    const submit_btn = raylib.Rectangle{ .x = submit_btn_x, .y = bottom_btn_y, .width = BOTTOM_BUTTON_WIDTH, .height = BOTTOM_BUTTON_HEIGHT };
    const answer_btn = raylib.Rectangle{ .x = answer_btn_x, .y = bottom_btn_y, .width = BOTTOM_BUTTON_WIDTH, .height = BOTTOM_BUTTON_HEIGHT };

    // Input box (centered vertically in main UI area)
    const input_box_x = @as(f32, @floatFromInt(@divTrunc((screen_width - INPUT_BOX_WIDTH), 2)));
    const input_box_y = @as(f32, @floatFromInt(question_y + MEDIUM_SPACING));
    const input_box = raylib.Rectangle{ .x = input_box_x, .y = input_box_y, .width = INPUT_BOX_WIDTH, .height = INPUT_BOX_HEIGHT };

    if (getInputEvent(state)) |input| {
        // Only handle press events for UI interactions (ignore releases)
        if (!input.pressed) return;

        const pos = input.position;
        if (raylib.checkCollisionPointRec(pos, submit_btn)) {
            state.game_state = .Submitting;
        } else if (raylib.checkCollisionPointRec(pos, answer_btn)) {
            startSession(state);
        } else if (state.game_state == .Submitting and raylib.checkCollisionPointRec(pos, input_box)) {
            state.input_active = true;
        } else if (state.game_state == .Submitting) {
            state.input_active = false;
        } else if (raylib.checkCollisionPointRec(pos, button_rect_true)) {
            state.selected = true;
            state.response.answer = true;
        } else if (raylib.checkCollisionPointRec(pos, button_rect_false)) {
            state.selected = false;
            state.response.answer = false;
        } else if (raylib.checkCollisionPointRec(pos, confirm_rect) and state.selected != null) {
            var r = currentResponse(state);
            const now = std.time.timestamp();
            r.answer = state.response.answer;
            r.duration = @as(f64, @floatFromInt(now - r.start_time));
            if (state.response.answer == state.session.questions[state.session.current].answer) state.session.correct += 1;
            state.session.current += 1;
            if (state.session.current >= 10) {
                state.session.finished = true;
                state.game_state = .Finished;
                state.user_session.trust = calcTrustScore(state);
                state.user_session.invitable = state.user_session.trust >= 0.85;
                submitResponseBatch(&state.user_session);
                if (state.user_session.trust >= 0.85 and !state.invited_shown) {
                    showInviteModal();
                    state.invited_shown = true;
                    // Temporarily disable JS interop to test alignment issue
                    // js.set_invited_shown(true);
                }
            }
            state.response.answer = null;
            state.selected = null;
        } else if (raylib.checkCollisionPointRec(pos, randomize_btn)) {
            const new_pal = randomPalette(state);
            state.bg_color = new_pal.bg;
            state.fg_color = new_pal.fg;
        }
    }
    // Handle text input if input_active
    if (state.game_state == .Submitting and state.input_active) {
        var key = raylib.getCharPressed();
        while (key > 0) : (key = raylib.getCharPressed()) {
            if (key >= 32 and key <= 126 and state.input_len < state.input_buffer.len - 1) {
                state.input_buffer[state.input_len] = @as(u8, @intCast(key));
                state.input_len += 1;
            }
        }
        if (raylib.isKeyPressed(.backspace) and state.input_len > 0) {
            state.input_len -= 1;
        }
        state.input_buffer[state.input_len] = 0;
    }
    // Per-question timer start
    if (state.game_state == .Answering and state.session.current < 10 and currentResponse(state).start_time == 0) {
        currentResponse(state).start_time = std.time.timestamp();
    }

    // Don't process input during loading
    if (state.game_state == .Loading) {
        return;
    }
}

pub export fn draw(state: *GameState) callconv(.C) void {
    const raylib = rl;
    raylib.beginDrawing();
    defer raylib.endDrawing();
    raylib.clearBackground(state.bg_color);
    const size = get_canvas_size();
    const screen_width = size.w;
    const screen_height = size.h;

    // Calculate vertical center and spacing for main UI (same as update)
    const ui_block_height = MEDIUM_FONT_SIZE + SMALL_SPACING + LARGE_FONT_SIZE + ELEMENT_SPACING + button_h + ELEMENT_SPACING + confirm_h;
    const ui_start_y = @divTrunc((screen_height - ui_block_height), 2);
    const progress_y = ui_start_y;
    const question_y = progress_y + MEDIUM_FONT_SIZE + SMALL_SPACING;
    const buttons_y = question_y + LARGE_FONT_SIZE + ELEMENT_SPACING;
    const confirm_button_y = buttons_y + button_h + ELEMENT_SPACING;

    if (state.game_state == .Loading) {
        // Loading screen
        const loading_width = raylib.measureText(state.loading_message, LARGE_FONT_SIZE);
        raylib.drawText(state.loading_message, @divTrunc((screen_width - loading_width), 2), question_y, LARGE_FONT_SIZE, state.fg_color);

        // Simple loading animation (spinning dots)
        const time = raylib.getTime();
        const dot_count = @as(usize, @intFromFloat(@mod(time, 3.0))) + 1;
        var loading_dots: [4]u8 = undefined;
        var i: usize = 0;
        while (i < dot_count and i < 3) : (i += 1) {
            loading_dots[i] = '.';
        }
        loading_dots[dot_count] = 0;
        const dots_text: [:0]const u8 = @ptrCast(loading_dots[0..dot_count :0]);
        const dots_width = raylib.measureText(dots_text, LARGE_FONT_SIZE);
        raylib.drawText(dots_text, @divTrunc((screen_width - dots_width), 2), question_y + MEDIUM_SPACING, LARGE_FONT_SIZE, state.fg_color);
    } else if (state.game_state == .Answering) {
        const qnum = state.session.current + 1;
        // Use a simpler approach to avoid WASM memory issues
        var qstr_buf: [32]u8 = undefined;
        const qstr = std.fmt.bufPrintZ(&qstr_buf, "Question: {}", .{qnum}) catch "Question: ?";
        const qstr_width = raylib.measureText(qstr, MEDIUM_FONT_SIZE);
        raylib.drawText(qstr, @divTrunc((screen_width - qstr_width), 2), progress_y, MEDIUM_FONT_SIZE, state.fg_color);

        // Center question text
        const question = state.session.questions[state.session.current].question;
        const question_width = raylib.measureText(question, LARGE_FONT_SIZE);
        raylib.drawText(question, @divTrunc((screen_width - question_width), 2), question_y, LARGE_FONT_SIZE, state.fg_color);

        // Center TRUE/FALSE buttons horizontally
        const total_button_width = button_w * 2 + BUTTON_GAP;
        const buttons_x = @as(f32, @floatFromInt(@divTrunc((screen_width - total_button_width), 2)));
        raylib.drawRectangleLinesEx(raylib.Rectangle{ .x = buttons_x, .y = @as(f32, @floatFromInt(buttons_y)), .width = button_w, .height = button_h }, if (state.selected == true) THICK_BORDER else THIN_BORDER, if (state.selected == true) accent else state.fg_color);
        raylib.drawText("TRUE", @as(i32, @intFromFloat(buttons_x)) + BUTTON_TEXT_OFFSET_X, buttons_y + BUTTON_TEXT_OFFSET_Y, LARGE_FONT_SIZE, state.fg_color);
        raylib.drawRectangleLinesEx(raylib.Rectangle{ .x = buttons_x + button_w + BUTTON_GAP, .y = @as(f32, @floatFromInt(buttons_y)), .width = button_w, .height = button_h }, if (state.selected == false) THICK_BORDER else THIN_BORDER, if (state.selected == false) accent else state.fg_color);
        raylib.drawText("FALSE", @as(i32, @intFromFloat(buttons_x)) + @as(i32, @intFromFloat(button_w)) + BUTTON_GAP + BUTTON_TEXT_OFFSET_X, buttons_y + BUTTON_TEXT_OFFSET_Y, LARGE_FONT_SIZE, state.fg_color);

        // Center confirm button
        const confirm_x = @as(f32, @floatFromInt(@divTrunc((screen_width - confirm_w), 2)));
        const confirm_color = if (state.selected != null) accent else rl.Color{ .r = 180, .g = 180, .b = 180, .a = 255 };
        raylib.drawRectangle(@as(i32, @intFromFloat(confirm_x)), confirm_button_y, @as(i32, @intFromFloat(confirm_w)), @as(i32, @intFromFloat(confirm_h)), confirm_color);
        raylib.drawText("CONFIRM", @as(i32, @intFromFloat(confirm_x)) + CONFIRM_TEXT_OFFSET_X, confirm_button_y + CONFIRM_TEXT_OFFSET_Y, MEDIUM_FONT_SIZE, .white);
    } else if (state.game_state == .Finished) {
        const thank_width = raylib.measureText("Thank you!", LARGE_FONT_SIZE);
        raylib.drawText("Thank you!", @divTrunc((screen_width - thank_width), 2), question_y, LARGE_FONT_SIZE, state.fg_color);
        // Use a simpler approach to avoid WASM memory issues
        var score_buf: [32]u8 = undefined;
        const score_str = std.fmt.bufPrintZ(&score_buf, "Score: {}/10", .{state.session.correct}) catch "Score: ?";
        const score_width = raylib.measureText(score_str, LARGE_FONT_SIZE);
        raylib.drawText(score_str, @divTrunc((screen_width - score_width), 2), question_y + MEDIUM_SPACING, LARGE_FONT_SIZE, state.fg_color);
    } else if (state.game_state == .Submitting) {
        const submit_width = raylib.measureText("Submit your own question!", LARGE_FONT_SIZE);
        raylib.drawText("Submit your own question!", @divTrunc((screen_width - submit_width), 2), question_y, LARGE_FONT_SIZE, state.fg_color);
        // Center input box
        const input_box_x = @as(f32, @floatFromInt(@divTrunc((screen_width - INPUT_BOX_WIDTH), 2)));
        const input_box_y = @as(f32, @floatFromInt(question_y + MEDIUM_SPACING));
        const input_box = rl.Rectangle{ .x = input_box_x, .y = input_box_y, .width = INPUT_BOX_WIDTH, .height = INPUT_BOX_HEIGHT };
        raylib.drawRectangleLinesEx(input_box, INPUT_BORDER, state.fg_color);
        const input_text = if (state.input_len > 0) @as([:0]const u8, @ptrCast(&state.input_buffer)) else "[Type your question here]";
        raylib.drawText(input_text, @as(i32, @intFromFloat(input_box_x)) + TEXT_PADDING, @as(i32, @intFromFloat(input_box_y)) + TEXT_PADDING, SMALL_FONT_SIZE, state.fg_color);
        if (state.input_active and (@mod(raylib.getTime() * 2.0, 2.0) < 1.0)) {
            const cursor_x = @as(i32, @intFromFloat(input_box_x)) + TEXT_PADDING + raylib.measureText(input_text, SMALL_FONT_SIZE);
            raylib.drawRectangle(cursor_x, @as(i32, @intFromFloat(input_box_y)) + TEXT_PADDING, CURSOR_WIDTH, CURSOR_HEIGHT, state.fg_color);
        }
    }
    // Always-visible UI
    // COLOR button in top right
    const randomize_btn_x = @as(f32, @floatFromInt(screen_width - COLOR_BUTTON_WIDTH - MARGIN));
    const randomize_btn_y = @as(f32, @floatFromInt(MARGIN));
    const randomize_btn = raylib.Rectangle{ .x = randomize_btn_x, .y = randomize_btn_y, .width = COLOR_BUTTON_WIDTH, .height = COLOR_BUTTON_HEIGHT };
    raylib.drawRectangleRec(randomize_btn, state.fg_color);
    const color_text = "COLOR";
    const color_font_size = MEDIUM_FONT_SIZE;
    const color_text_width = raylib.measureText(color_text, color_font_size);
    const color_text_x = @as(i32, @intFromFloat(randomize_btn_x)) + @divTrunc((COLOR_BUTTON_WIDTH - color_text_width), 2);
    const color_text_y = @as(i32, @intFromFloat(randomize_btn_y)) + @divTrunc((COLOR_BUTTON_HEIGHT - color_font_size), 2);
    raylib.drawText(color_text, color_text_x, color_text_y, color_font_size, state.bg_color);
    // SUBMIT and ANSWER buttons in bottom right
    const bottom_btn_y = @as(f32, @floatFromInt(screen_height - BOTTOM_BUTTON_HEIGHT - MARGIN));
    const answer_btn_x = @as(f32, @floatFromInt(screen_width - BOTTOM_BUTTON_WIDTH - MARGIN));
    const submit_btn_x = answer_btn_x - BOTTOM_BUTTON_WIDTH - BOTTOM_BUTTON_GAP;
    raylib.drawRectangleRec(rl.Rectangle{ .x = submit_btn_x, .y = bottom_btn_y, .width = BOTTOM_BUTTON_WIDTH, .height = BOTTOM_BUTTON_HEIGHT }, state.fg_color);
    raylib.drawText("SUBMIT", @as(i32, @intFromFloat(submit_btn_x)) + TEXT_PADDING, @as(i32, @intFromFloat(bottom_btn_y)) + TEXT_PADDING, SMALL_FONT_SIZE, state.bg_color);
    raylib.drawRectangleRec(rl.Rectangle{ .x = answer_btn_x, .y = bottom_btn_y, .width = BOTTOM_BUTTON_WIDTH, .height = BOTTOM_BUTTON_HEIGHT }, state.fg_color);
    raylib.drawText("ANSWER", @as(i32, @intFromFloat(answer_btn_x)) + TEXT_PADDING, @as(i32, @intFromFloat(bottom_btn_y)) + TEXT_PADDING, SMALL_FONT_SIZE, state.bg_color);

    if (state.user_trust >= 0.85 and state.game_state == .Answering) {
        for (state.session.questions[state.session.current].tags) |tag| {
            _ = tag;
            // Optionally draw tags
        }
    }
}

pub export fn reload(state: *GameState) callconv(.C) void {
    _ = state;
}

pub export fn stateSize() callconv(.C) usize {
    return @sizeOf(GameState);
}

// Callback function for fetch_questions API response
export fn on_questions_received(success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void {
    if (g_state == null) return;
    const state = g_state.?;

    if (success == 0) {
        // Error occurred
        const error_msg = data_ptr[0..data_len];
        std.debug.print("Failed to fetch questions: {s}\n", .{error_msg});
        state.loading_message = "Failed to load questions. Using fallback.";
        // Use fallback questions
        initSessionWithFallback(state);
        return;
    }

    // Parse JSON response
    const json_str = data_ptr[0..data_len];
    std.debug.print("Received questions JSON: {s}\n", .{json_str});

    // For now, use fallback questions until we implement JSON parsing
    // TODO: Parse JSON and extract questions
    state.loading_message = "Questions loaded!";
    initSessionWithFallback(state);
}

fn initSessionWithFallback(state: *GameState) void {
    state.session = Session{
        .questions = question_pool,
        .current = 0,
        .correct = 0,
        .finished = false,
    };
    state.user_session.timestamp = std.time.timestamp();
    state.user_session.session_id = "dummy-session";
    state.user_session.token = "dummy-token";
    state.user_session.trust = state.user_trust;
    state.user_session.invitable = false;
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        state.user_session.responses[i] = QuestionResponse{
            .question_id = state.session.questions[i].id,
            .answer = null,
            .start_time = 0,
            .duration = 0.0,
        };
    }
    state.game_state = .Answering;
}
