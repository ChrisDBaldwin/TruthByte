const std = @import("std");
const rl = @import("raylib");

// Import our modules
const types = @import("types.zig");
const utils = @import("utils.zig");
const input = @import("input.zig");
const api = @import("api.zig");
const render = @import("render.zig");

// --- Exported API ---

pub export fn init(allocator: *std.mem.Allocator) callconv(.C) *anyopaque {
    const state = allocator.create(types.GameState) catch unreachable;
    utils.initPalettes(state);
    state.prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));
    const pal = utils.randomPalette(state);
    state.bg_color = pal.bg;
    state.fg_color = pal.fg;

    api.startAuthentication(state);
    state.input_active = false;
    state.input_len = 0;
    state.input_buffer[0] = 0;
    state.response = types.QuestionResponse{ .question_id = "q001", .answer = null };
    state.selected = null;
    // Ensure proper alignment when returning
    return @ptrCast(@alignCast(state));
}

pub export fn deinit(allocator: *std.mem.Allocator, state: *types.GameState) callconv(.C) void {
    allocator.destroy(state);
}

pub export fn update(state: *types.GameState) callconv(.C) void {
    const size = utils.get_canvas_size();
    const screen_width = size.w;
    const screen_height = size.h;

    // Update Raylib's render size if the canvas size changed
    if (state.last_screen_width != screen_width or state.last_screen_height != screen_height) {
        rl.setWindowSize(screen_width, screen_height);
        state.last_screen_width = screen_width;
        state.last_screen_height = screen_height;
    }

    // Update orientation based on screen dimensions
    const new_orientation: types.Orientation = if (screen_width > screen_height) .Horizontal else .Vertical;
    if (state.orientation != new_orientation) {
        state.orientation = new_orientation;
        std.debug.print("🔄 Orientation changed to: {}\n", .{state.orientation});
    }

    // Don't process input during loading
    if (state.game_state == .Loading or state.game_state == .Authenticating) {
        return;
    }

    // Calculate layout for UI interaction
    const layout = render.calculateLayout(state);

    // Handle input events
    if (input.getInputEvent(state)) |input_event| {
        // Only handle press events for UI interactions (ignore releases)
        if (!input_event.pressed) return;

        const pos = input_event.position;
        if (rl.checkCollisionPointRec(pos, layout.submit_btn)) {
            state.game_state = .Submitting;
        } else if (rl.checkCollisionPointRec(pos, layout.answer_btn)) {
            api.startSession(state);
        } else if (state.game_state == .Submitting and rl.checkCollisionPointRec(pos, layout.input_box)) {
            state.input_active = true;
        } else if (state.game_state == .Submitting) {
            state.input_active = false;
        } else if (rl.checkCollisionPointRec(pos, layout.button_rect_true)) {
            state.selected = true;
            state.response.answer = true;
        } else if (rl.checkCollisionPointRec(pos, layout.button_rect_false)) {
            state.selected = false;
            state.response.answer = false;
        } else if (rl.checkCollisionPointRec(pos, layout.confirm_rect) and state.selected != null) {
            var r = utils.currentResponse(state);
            const now = std.time.timestamp();
            r.answer = state.response.answer;
            r.duration = @as(f64, @floatFromInt(now - r.start_time));
            if (state.response.answer == state.session.questions[state.session.current].answer) state.session.correct += 1;
            state.session.current += 1;
            if (state.session.current >= 7) {
                std.debug.print("🏁 Game completed! Transitioning to Finished state...\n", .{});
                state.session.finished = true;
                state.game_state = .Finished;
                state.user_session.trust = utils.calcTrustScore(state);
                state.user_session.invitable = state.user_session.trust >= 0.85;
                std.debug.print("📊 Trust score calculated: {d}\n", .{state.user_session.trust});
                api.submitResponseBatch(&state.user_session);
                if (state.user_session.trust >= 0.85 and !state.invited_shown) {
                    utils.showInviteModal();
                    state.invited_shown = true;
                    utils.js.set_invited_shown(true);
                }
            }
            state.response.answer = null;
            state.selected = null;
        } else if (state.game_state == .Finished and rl.checkCollisionPointRec(pos, layout.continue_rect)) {
            // Continue button clicked - start a new session
            api.startSession(state);
        } else if (rl.checkCollisionPointRec(pos, layout.randomize_btn)) {
            const new_pal = utils.randomPalette(state);
            state.bg_color = new_pal.bg;
            state.fg_color = new_pal.fg;
        }
    }

    // Handle text input
    input.handleTextInput(state);

    // Per-question timer start
    if (state.game_state == .Answering and state.session.current < 7 and utils.currentResponse(state).start_time == 0) {
        utils.currentResponse(state).start_time = std.time.timestamp();
    }
}

pub export fn draw(state: *types.GameState) callconv(.C) void {
    render.draw(state);
}

pub export fn reload(state: *types.GameState) callconv(.C) void {
    _ = state;
}

pub export fn stateSize() callconv(.C) usize {
    return @sizeOf(types.GameState);
}
