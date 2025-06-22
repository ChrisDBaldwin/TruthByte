const std = @import("std");
const rl = @import("raylib");

// Import our modules
const types = @import("types.zig");
const utils = @import("utils.zig");
const input = @import("input.zig");
const api = @import("api.zig");
const render = @import("render.zig");

// --- Helper Functions ---

fn submitQuestion(state: *types.GameState) void {
    if (state.input_len < 5) return; // Minimum question length

    // Create a question submission JSON
    var json_buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&json_buffer);
    const allocator = fba.allocator();

    // Get the question text
    const question_text = state.input_buffer[0..state.input_len];

    // Create submission data
    const submission = .{
        .question = question_text,
        .submitter_id = utils.js.get_session_id_slice(),
        .suggested_answer = true, // Default to true, moderators can change
        .tags = &[_][]const u8{"user-submitted"},
    };

    const json_str = std.json.stringifyAlloc(allocator, submission, .{}) catch |err| {
        std.debug.print("❌ Failed to serialize question submission: {any}\n", .{err});
        return;
    };

    std.debug.print("📝 Submitting question: {s}\n", .{json_str});

    // Call the propose_question API
    utils.js.propose_question(json_str.ptr, json_str.len, onQuestionSubmitted);

    // Clear input and show feedback
    state.input_len = 0;
    state.input_buffer[0] = 0;
    state.input_active = false;

    // Go back to previous state
    if (state.session.finished) {
        state.game_state = .Finished;
    } else {
        state.game_state = .Answering;
    }
}

// Callback for question submission
export fn onQuestionSubmitted(success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void {
    if (success == 1) {
        std.debug.print("✅ Question submitted successfully!\n", .{});
        // Could show a success message to the user here
    } else {
        const error_msg = if (data_len > 0) data_ptr[0..data_len] else "Unknown error";
        std.debug.print("❌ Failed to submit question: {s}\n", .{error_msg});
    }
}

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
    // Always update screen size and orientation every frame (no throttling)
    const size = utils.get_canvas_size();
    state.last_screen_width = size.w;
    state.last_screen_height = size.h;
    const aspect_ratio = @as(f32, @floatFromInt(size.w)) / @as(f32, @floatFromInt(size.h));
    state.orientation = if (aspect_ratio > 1.2) .Horizontal else .Vertical;

    // Track state transitions on mobile
    const is_mobile = size.w < 600 and size.h > size.w;

    // Don't process input during loading, but check for timeout
    if (state.game_state == .Loading or state.game_state == .Authenticating) {
        // Check for loading timeout (10 seconds for better UX)
        const current_time = std.time.timestamp();
        const loading_duration = current_time - state.loading_start_time;
        if (loading_duration > 10) {
            std.debug.print("⏰ Loading timeout after {} seconds, using fallback. Game state: {any}, Auth: {}\n", .{ loading_duration, state.game_state, state.auth_initialized });
            state.loading_message = "Connection timeout. Using offline mode.";
            api.initSessionWithFallback(state);
        } else if (loading_duration > 5) {
            // Show intermediate message
            if (state.game_state == .Authenticating) {
                state.loading_message = "Still connecting...";
            } else {
                state.loading_message = "Still loading questions...";
            }
        }

        // Allow manual fallback after 8 seconds by tapping
        if (loading_duration > 8) {
            if (input.getInputEvent(state)) |input_event| {
                if (input_event.pressed) {
                    state.loading_message = "Switching to offline mode...";
                    api.initSessionWithFallback(state);
                }
            }
        }

        // Emergency state fix for mobile - if stuck in loading for too long, force answering state
        if (loading_duration > 12 and is_mobile) {
            std.debug.print("🚨 Emergency mobile fix: forcing answering state\n", .{});
            if (state.session.questions.len == 0 or state.session.questions[0].question.len == 0) {
                // Session not properly initialized, use fallback
                api.initSessionWithFallback(state);
            } else {
                // Session seems initialized but stuck in loading state
                state.game_state = .Answering;
            }
        }
        return;
    }

    // Handle input events
    if (input.getInputEvent(state)) |input_event| {
        // Calculate layout only when we have input (performance optimization)
        const layout = render.calculateLayout(state);
        // Only handle press events for UI interactions (ignore releases)
        if (!input_event.pressed) return;

        const pos = input_event.position;
        if (rl.checkCollisionPointRec(pos, layout.submit_btn) and render.shouldShowSubmitButton(state)) {
            state.game_state = .Submitting;
        } else if (rl.checkCollisionPointRec(pos, layout.answer_btn)) {
            api.startSession(state);
        } else if (state.game_state == .Submitting and rl.checkCollisionPointRec(pos, layout.input_box)) {
            state.input_active = true;
        } else if (state.game_state == .Submitting) {
            // Check for submission UI buttons - get responsive constants
            const constants = render.getResponsiveConstants();
            const submit_question_y = @as(i32, @intFromFloat(layout.input_box.y)) + types.INPUT_BOX_HEIGHT + 20;
            const submit_question_rect = rl.Rectangle{ .x = layout.input_box.x, .y = @as(f32, @floatFromInt(submit_question_y)), .width = constants.confirm_w, .height = constants.confirm_h };

            if (state.input_len > 5 and rl.checkCollisionPointRec(pos, submit_question_rect)) {
                // Submit the question
                submitQuestion(state);
            } else if (rl.checkCollisionPointRec(pos, layout.back_btn)) {
                // Go back to previous state
                if (state.session.finished) {
                    state.game_state = .Finished;
                } else {
                    state.game_state = .Answering;
                }
                state.input_active = false;
                state.input_len = 0;
                state.input_buffer[0] = 0;
            } else {
                state.input_active = false;
            }
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
                state.sessions_completed += 1; // Track completed sessions
                state.user_session.trust = utils.calcTrustScore(state);
                state.user_trust = state.user_session.trust; // Update user trust for UI gating
                state.user_session.invitable = state.user_session.trust >= 0.85;
                std.debug.print("📊 Trust score calculated: {d} (Sessions completed: {})\n", .{ state.user_session.trust, state.sessions_completed });
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

// Notify Zig/raylib when the canvas is resized (called from JavaScript)
pub export fn onCanvasResize(new_width: i32, new_height: i32) callconv(.C) void {
    const builtin = @import("builtin");
    if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) {
        // Force raylib to acknowledge the new canvas size
        rl.setWindowSize(new_width, new_height);

        // Update orientation and screen size in the global state if available
        const api_mod = @import("api.zig");
        if (api_mod.g_state) |state| {
            state.last_screen_width = new_width;
            state.last_screen_height = new_height;
            const aspect_ratio = @as(f32, @floatFromInt(new_width)) / @as(f32, @floatFromInt(new_height));
            state.orientation = if (aspect_ratio > 1.2) .Horizontal else .Vertical;
        }

        std.debug.print("🔄 Canvas resized to {}x{} (notified from JS)\n", .{ new_width, new_height });
    }
}
