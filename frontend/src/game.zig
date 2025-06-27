const std = @import("std");
const rl = @import("raylib");

// Import our modules
const types = @import("types.zig");
const utils = @import("utils.zig");
const input = @import("input.zig");
const api = @import("api.zig");
const render = @import("render.zig");
const user = @import("user.zig");

// --- Helper Functions ---

fn submitQuestion(state: *types.GameState) void {
    // Get the question text and tags (ensure null termination)
    const question_text = state.input_buffer[0..state.input_len];
    const tags_text = state.tags_input_buffer[0..state.tags_input_len];

    // SECURITY: Validate input before processing
    if (!input.validateQuestionInput(question_text, tags_text)) {
        // Invalid input - clear and return to prevent submission
        state.input_len = 0;
        state.input_buffer[0] = 0;
        state.tags_input_len = 0;
        state.tags_input_buffer[0] = 0;
        state.input_active = false;
        state.tags_input_active = false;
        state.submit_answer_selected = null;
        return;
    }

    if (state.submit_answer_selected == null) return; // Answer is required

    // Use a much larger buffer for JSON and tag storage
    var json_buffer: [4096]u8 = undefined;
    var tag_storage_buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&json_buffer);
    var tag_fba = std.heap.FixedBufferAllocator.init(&tag_storage_buffer);
    const allocator = fba.allocator();
    const tag_allocator = tag_fba.allocator();

    // Safety check: If tags_text contains JSON-like content, it's corrupted
    if (std.mem.indexOf(u8, tags_text, "\"question\"") != null or
        std.mem.indexOf(u8, tags_text, "{") != null or
        std.mem.indexOf(u8, tags_text, "}") != null)
    {

        // Use fallback tags
        var tags_list = std.ArrayList([]const u8).init(allocator);
        defer tags_list.deinit();

        const fallback_tag = tag_allocator.dupe(u8, "user-submitted") catch {
            return;
        };
        tags_list.append(fallback_tag) catch {
            return;
        };

        // Continue with submission using fallback tag
        const submission = .{
            .question = question_text,
            .answer = state.submit_answer_selected.?,
            .title = "",
            .passage = "",
            .categories = tags_list.items,
        };

        const json_str = std.json.stringifyAlloc(allocator, submission, .{}) catch {
            return;
        };

        const user_id_slice = user.getUserIDSlice();
        utils.js.propose_question(json_str.ptr, json_str.len, user_id_slice.ptr, user_id_slice.len, onQuestionSubmitted);

        // Clear input and go to thank you screen
        state.input_len = 0;
        state.input_buffer[0] = 0;
        state.input_active = false;
        state.tags_input_len = 0;
        state.tags_input_buffer[0] = 0;
        state.tags_input_active = false;
        state.submit_answer_selected = null;

        // Go to thank you screen
        state.game_state = .SubmitThanks;
        return;
    }

    // Normal tag parsing (when not corrupted)
    var tags_list = std.ArrayList([]const u8).init(allocator);
    defer tags_list.deinit();

    // Parse tags - split by comma and create persistent copies
    var tag_iter = std.mem.splitSequence(u8, tags_text, ",");
    var tag_count: u32 = 0;
    while (tag_iter.next()) |tag| {
        if (tag_count >= 5) break; // Limit number of tags

        const trimmed = std.mem.trim(u8, tag, " \t\n\r");
        if (trimmed.len > 0 and trimmed.len <= 50) { // Reasonable tag length limit
            // SECURITY: Additional validation for each tag
            var is_valid_tag = true;
            for (trimmed) |char| {
                if (!input.isSafeTagChar(char)) {
                    is_valid_tag = false;
                    break;
                }
            }

            if (is_valid_tag) {
                // Create a persistent copy of the trimmed tag
                const tag_copy = tag_allocator.dupe(u8, trimmed) catch {
                    continue;
                };
                tags_list.append(tag_copy) catch {
                    continue;
                };
                tag_count += 1;
            }
        }
    }

    // Ensure we have at least one tag
    if (tags_list.items.len == 0) {
        const default_tag = tag_allocator.dupe(u8, "user-submitted") catch {
            return;
        };
        tags_list.append(default_tag) catch {
            return;
        };
    }

    // Create submission data matching the backend API
    const submission = .{
        .question = question_text,
        .answer = state.submit_answer_selected.?,
        .title = "", // Optional - empty for now
        .passage = "", // Optional - empty for now
        .categories = tags_list.items,
    };

    // Try to stringify with error handling
    const json_str = std.json.stringifyAlloc(allocator, submission, .{}) catch {
        return;
    };

    // Call the propose_question API
    const user_id_slice = user.getUserIDSlice();
    utils.js.propose_question(json_str.ptr, json_str.len, user_id_slice.ptr, user_id_slice.len, onQuestionSubmitted);

    // Clear input and show thank you screen
    state.input_len = 0;
    state.input_buffer[0] = 0;
    state.input_active = false;
    state.tags_input_len = 0;
    state.tags_input_buffer[0] = 0;
    state.tags_input_active = false;
    state.submit_answer_selected = null;

    // Go to thank you screen instead of back to previous state
    state.game_state = .SubmitThanks;
}

// Callback for question submission
export fn onQuestionSubmitted(success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void {
    if (success == 1) {
        // Could show a success message to the user here
    } else {
        const error_msg = if (data_len > 0) data_ptr[0..data_len] else "Unknown error";
        // Could show error message to user here
        _ = error_msg;
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

    // Initialize user ID management
    user.initUserID(&state.prng);

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

        // COLOR button - handle first so it works in all states where sidebar is visible
        if (rl.checkCollisionPointRec(pos, layout.randomize_btn)) {
            // Check if sidebar should be visible (same logic as in render.zig)
            const canvas_size = utils.get_canvas_size();
            const current_aspect_ratio = @as(f32, @floatFromInt(canvas_size.w)) / @as(f32, @floatFromInt(canvas_size.h));
            const is_horizontal = current_aspect_ratio > 1.2;

            const should_show_sidebar = switch (state.game_state) {
                .Loading, .Authenticating => false,
                .Answering, .Finished, .Submitting, .SubmitThanks => true,
                .ModeSelection, .CategorySelection, .DailyReview => is_horizontal,
            };

            if (should_show_sidebar) {
                const new_pal = utils.randomPalette(state);
                state.bg_color = new_pal.bg;
                state.fg_color = new_pal.fg;
            }
        } else if (rl.checkCollisionPointRec(pos, layout.submit_btn) and render.shouldShowSubmitButton(state)) {
            state.game_state = .Submitting;
            // Initialize submit form state cleanly
            state.input_active = false;
            state.tags_input_active = false;
            state.input_len = 0;
            state.input_buffer[0] = 0;
            state.tags_input_len = 0;
            state.tags_input_buffer[0] = 0;
            state.submit_answer_selected = null;
        } else if (rl.checkCollisionPointRec(pos, layout.answer_btn)) {
            // NEW GAME button - only respond if not in submit mode
            const hide_side_buttons = state.game_state == .Submitting or state.game_state == .SubmitThanks;
            if (!hide_side_buttons) {
                api.startModeSelection(state);
            }
            // Categories button removed - now available through mode selection TODO: add back or remove
            // } else if (rl.checkCollisionPointRec(pos, layout.categories_btn)) {
            //     // CATEGORIES button - start category selection
            //     const hide_side_buttons = state.game_state == .Submitting or state.game_state == .SubmitThanks;
            //     if (!hide_side_buttons) {
            //         api.startCategorySelection(state);
            //     }
        } else if (state.game_state == .ModeSelection) {
            // Handle mode selection interactions
            if (rl.checkCollisionPointRec(pos, layout.arcade_mode_btn)) {
                api.startArcadeMode(state);
            } else if (rl.checkCollisionPointRec(pos, layout.categories_mode_btn)) {
                api.startCategoriesMode(state);
            } else if (rl.checkCollisionPointRec(pos, layout.daily_mode_btn)) {
                api.startDailyMode(state);
            }
        } else if (state.game_state == .DailyReview) {
            // Handle DailyReview state - check for continue button
            // Calculate the same button position as in drawDailyReviewScreen
            const button_y = layout.question_y + 200; // 40px buffer below last text
            const continue_rect = rl.Rectangle{
                .x = @floatFromInt(@divTrunc(layout.screen_width - 200, 2)),
                .y = @floatFromInt(button_y),
                .width = 200,
                .height = 40,
            };

            if (rl.checkCollisionPointRec(pos, continue_rect)) {
                // Continue button clicked - go back to mode selection
                api.startModeSelection(state);
            }
        } else if (state.game_state == .CategorySelection) {
            // Handle category selection interactions
            if (rl.checkCollisionPointRec(pos, layout.back_btn)) {
                // Back button - return to mode selection (not to a game session)
                api.startModeSelection(state);
            } else {
                // Check if any category was clicked
                for (0..state.categories_count) |i| {
                    if (rl.checkCollisionPointRec(pos, layout.category_buttons[i])) {
                        // Category selected - start session with this category
                        const selected_category = state.available_categories[i];

                        // Copy category name to state buffer
                        const name_len = @min(selected_category.name.len, state.selected_category_name.len - 1);
                        @memcpy(state.selected_category_name[0..name_len], selected_category.name[0..name_len]);
                        state.selected_category_name[name_len] = 0;
                        state.selected_category_len = name_len;

                        // Start session with selected category
                        const category_slice = state.selected_category_name[0..state.selected_category_len];
                        api.startSessionWithCategory(state, category_slice, state.selected_difficulty);
                        break;
                    }
                }

                // Check difficulty filter buttons
                for (1..6) |difficulty| {
                    if (rl.checkCollisionPointRec(pos, layout.difficulty_buttons[difficulty - 1])) {
                        // Toggle difficulty filter
                        if (state.selected_difficulty) |selected_difficulty| {
                            if (selected_difficulty == difficulty) {
                                state.selected_difficulty = null; // Deselect
                            } else {
                                state.selected_difficulty = @as(?u8, @intCast(difficulty));
                            }
                        } else {
                            state.selected_difficulty = @as(?u8, @intCast(difficulty));
                        }
                        break;
                    }
                }
            }
        } else if (state.game_state == .Submitting and rl.checkCollisionPointRec(pos, layout.input_box)) {
            // Save current input value if we're switching from tags to question
            if (state.tags_input_active and utils.js.isTextInputFocused()) {
                const current_text = utils.js.getTextInputValueSlice();
                const copy_len = @min(current_text.len, state.tags_input_buffer.len - 1);
                @memcpy(state.tags_input_buffer[0..copy_len], current_text[0..copy_len]);
                state.tags_input_len = copy_len;
                state.tags_input_buffer[state.tags_input_len] = 0;
            }

            state.input_active = true;
            state.tags_input_active = false;

            // Show text input field for question input and load current question text
            _ = utils.js.showTextInputWithString(@as(i32, @intFromFloat(layout.input_box.x)), @as(i32, @intFromFloat(layout.input_box.y)), @as(i32, @intFromFloat(layout.input_box.width)), @as(i32, @intFromFloat(layout.input_box.height)), "Enter your question...");

            // Set the input value to current question text
            const question_text = state.input_buffer[0..state.input_len];
            _ = utils.js.setTextInputValueFromString(question_text);
        } else if (state.game_state == .Submitting and rl.checkCollisionPointRec(pos, layout.tags_input_box)) {
            // Save current input value if we're switching from question to tags
            if (state.input_active and utils.js.isTextInputFocused()) {
                const current_text = utils.js.getTextInputValueSlice();
                const copy_len = @min(current_text.len, state.input_buffer.len - 1);
                @memcpy(state.input_buffer[0..copy_len], current_text[0..copy_len]);
                state.input_len = copy_len;
                state.input_buffer[state.input_len] = 0;
            }

            state.tags_input_active = true;
            state.input_active = false;

            // Show text input field for tags input and load current tags text
            _ = utils.js.showTextInputWithString(@as(i32, @intFromFloat(layout.tags_input_box.x)), @as(i32, @intFromFloat(layout.tags_input_box.y)), @as(i32, @intFromFloat(layout.tags_input_box.width)), @as(i32, @intFromFloat(layout.tags_input_box.height)), "Enter tags (comma separated)...");

            // Set the input value to current tags text
            const tags_text = state.tags_input_buffer[0..state.tags_input_len];
            _ = utils.js.setTextInputValueFromString(tags_text);
        } else if (state.game_state == .Submitting) {
            // Check for answer selection buttons
            if (rl.checkCollisionPointRec(pos, layout.submit_true_btn)) {
                state.submit_answer_selected = true;
            } else if (rl.checkCollisionPointRec(pos, layout.submit_false_btn)) {
                state.submit_answer_selected = false;
            } else if (rl.checkCollisionPointRec(pos, layout.submit_question_btn)) {
                // Save current input value before submitting
                if (utils.js.isTextInputFocused()) {
                    const current_text = utils.js.getTextInputValueSlice();
                    if (state.input_active) {
                        const copy_len = @min(current_text.len, state.input_buffer.len - 1);
                        @memcpy(state.input_buffer[0..copy_len], current_text[0..copy_len]);
                        state.input_len = copy_len;
                        state.input_buffer[state.input_len] = 0;
                    } else if (state.tags_input_active) {
                        const copy_len = @min(current_text.len, state.tags_input_buffer.len - 1);
                        @memcpy(state.tags_input_buffer[0..copy_len], current_text[0..copy_len]);
                        state.tags_input_len = copy_len;
                        state.tags_input_buffer[state.tags_input_len] = 0;
                    }
                }

                // Submit the question - check all required fields
                if (state.input_len >= 5 and state.submit_answer_selected != null and state.tags_input_len > 0) {
                    submitQuestion(state);
                    // Hide the text input after submission
                    _ = utils.js.hideTextInput();
                }
            } else if (rl.checkCollisionPointRec(pos, layout.back_btn)) {
                // Save current input value before going back
                if (utils.js.isTextInputFocused()) {
                    const current_text = utils.js.getTextInputValueSlice();
                    if (state.input_active) {
                        const copy_len = @min(current_text.len, state.input_buffer.len - 1);
                        @memcpy(state.input_buffer[0..copy_len], current_text[0..copy_len]);
                        state.input_len = copy_len;
                        state.input_buffer[state.input_len] = 0;
                    } else if (state.tags_input_active) {
                        const copy_len = @min(current_text.len, state.tags_input_buffer.len - 1);
                        @memcpy(state.tags_input_buffer[0..copy_len], current_text[0..copy_len]);
                        state.tags_input_len = copy_len;
                        state.tags_input_buffer[state.tags_input_len] = 0;
                    }
                }

                // Go back to previous state
                if (state.session.finished) {
                    state.game_state = .Finished;
                } else {
                    state.game_state = .Answering;
                }
                state.input_active = false;
                state.input_len = 0;
                state.input_buffer[0] = 0;
                state.tags_input_active = false;
                state.tags_input_len = 0;
                state.tags_input_buffer[0] = 0;
                state.submit_answer_selected = null;
                // Hide the text input when going back
                _ = utils.js.hideTextInput();
            }
        } else if (state.game_state == .SubmitThanks) {
            // Handle SubmitThanks state - check for continue/submit another buttons
            // Calculate the same button positions as in drawSubmitThanksScreen
            const constants = render.getResponsiveConstants();
            const button_spacing = types.ELEMENT_SPACING + 20; // Extra buffer space between buttons
            const button_width = constants.confirm_w;
            const button_height = constants.confirm_h;

            // Calculate total height needed for both buttons with spacing
            const total_buttons_height = @as(i32, @intFromFloat(button_height * 2)) + button_spacing;

            // Center the button group vertically in the available space below the message
            const title_y = layout.question_y - 60;
            const message_y = title_y + constants.large_font + types.SMALL_SPACING;
            const available_space_start = message_y + constants.medium_font + types.ELEMENT_SPACING;
            const available_space_height = layout.screen_height - available_space_start - constants.margin;
            const buttons_start_y = available_space_start + @divTrunc((available_space_height - total_buttons_height), 2);

            // Ensure buttons don't go too high or too low
            const safe_buttons_start_y = @max(buttons_start_y, available_space_start);
            const safe_buttons_start_y_final = @min(safe_buttons_start_y, layout.screen_height - total_buttons_height - constants.margin);

            // Submit Another button (first button)
            const submit_button_x = @divTrunc((layout.screen_width - @as(i32, @intFromFloat(button_width))), 2);
            const submit_button_y = safe_buttons_start_y_final;
            const submit_button_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(submit_button_x)), .y = @as(f32, @floatFromInt(submit_button_y)), .width = button_width, .height = button_height };

            // Back to Game button (second button, with buffer space)
            const back_button_x = submit_button_x;
            const back_button_y = submit_button_y + @as(i32, @intFromFloat(button_height)) + button_spacing;
            const back_button_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(back_button_x)), .y = @as(f32, @floatFromInt(back_button_y)), .width = button_width, .height = button_height };

            if (rl.checkCollisionPointRec(pos, submit_button_rect)) {
                // "Submit Another" button - go back to submitting state
                state.game_state = .Submitting;
                // Initialize submit form state cleanly
                state.input_active = false;
                state.tags_input_active = false;
                state.input_len = 0;
                state.input_buffer[0] = 0;
                state.tags_input_len = 0;
                state.tags_input_buffer[0] = 0;
                state.submit_answer_selected = null;
            } else if (rl.checkCollisionPointRec(pos, back_button_rect)) {
                // "Back to Game" button - go back to appropriate state
                if (state.session.finished) {
                    state.game_state = .Finished;
                } else {
                    state.game_state = .Answering;
                }
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

            // Check if this was the last question BEFORE incrementing
            const was_last_question = (state.session.current + 1) >= state.session.total_questions;
            state.session.current += 1;

            if (was_last_question) {
                state.session.finished = true;
                state.sessions_completed += 1; // Track completed sessions
                state.user_session.trust = utils.calcTrustScore(state);
                state.user_trust = state.user_session.trust; // Update user trust for UI gating

                // Handle different completion flows based on mode
                if (state.session.mode == .Daily) {
                    // Submit daily answers
                    api.submitDailyAnswers(state);
                } else {
                    // Regular arcade/categories mode
                    state.game_state = .Finished;
                    api.submitResponseBatch(&state.user_session);
                }
            }
            state.response.answer = null;
            state.selected = null;
        } else if (state.game_state == .Finished and rl.checkCollisionPointRec(pos, layout.continue_rect)) {
            // Continue button clicked - go back to mode selection instead of immediately starting session
            api.startModeSelection(state);
        } else {
            // Clicked outside any interactive elements
            if (state.game_state == .Submitting) {
                // If clicking outside input areas while in submitting state, hide text input
                if (!rl.checkCollisionPointRec(pos, layout.input_box) and
                    !rl.checkCollisionPointRec(pos, layout.tags_input_box))
                {
                    state.input_active = false;
                    state.tags_input_active = false;
                    _ = utils.js.hideTextInput();
                }
            }
        }
    }

    // Handle text input
    input.handleTextInput(state);

    // Per-question timer start
    if (state.game_state == .Answering and state.session.current < state.session.total_questions and utils.currentResponse(state).start_time == 0) {
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
    }
}
