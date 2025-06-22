const std = @import("std");
const rl = @import("raylib");
const types = @import("types.zig");
const utils = @import("utils.zig");

// --- Canvas Size Struct ---
pub const CanvasSize = struct { w: i32, h: i32 };

// --- UI Layout Calculation Functions ---

pub fn getResponsiveConstants() struct {
    margin: i32,
    large_font: i32,
    medium_font: i32,
    small_font: i32,
    button_w: f32,
    button_h: f32,
    button_gap: i32,
    confirm_w: f32,
    confirm_h: f32,
} {
    const size = utils.get_canvas_size();

    // Pure size-based responsive breakpoints (no device detection)
    if (size.w < 350 or size.h < 400) {
        // Extra small screens
        return .{
            .margin = 8,
            .large_font = 14,
            .medium_font = 12,
            .small_font = 10,
            .button_w = 100,
            .button_h = 45,
            .button_gap = 15,
            .confirm_w = 120,
            .confirm_h = 40,
        };
    } else if (size.w < 600) {
        // Small screens (mobile)
        return .{
            .margin = 12,
            .large_font = 18,
            .medium_font = 15,
            .small_font = 12,
            .button_w = 140,
            .button_h = 55,
            .button_gap = 20,
            .confirm_w = 160,
            .confirm_h = 45,
        };
    } else if (size.w < 900) {
        // Medium screens
        return .{
            .margin = 18,
            .large_font = 24,
            .medium_font = 18,
            .small_font = 14,
            .button_w = 200,
            .button_h = 70,
            .button_gap = 30,
            .confirm_w = 180,
            .confirm_h = 55,
        };
    } else {
        // Large screens
        return .{
            .margin = 24,
            .large_font = 32,
            .medium_font = 22,
            .small_font = 16,
            .button_w = 240,
            .button_h = 80,
            .button_gap = 40,
            .confirm_w = 200,
            .confirm_h = 60,
        };
    }
}

pub const UILayout = struct {
    screen_width: i32,
    screen_height: i32,
    ui_block_height: i32,
    ui_start_y: i32,
    progress_y: i32,
    question_y: i32,
    buttons_y: i32,
    confirm_button_y: i32,
    continue_button_y: i32,
    // Button rectangles
    button_rect_true: rl.Rectangle,
    button_rect_false: rl.Rectangle,
    confirm_rect: rl.Rectangle,
    continue_rect: rl.Rectangle,
    randomize_btn: rl.Rectangle,
    submit_btn: rl.Rectangle,
    answer_btn: rl.Rectangle,
    input_box: rl.Rectangle,
    back_btn: rl.Rectangle,
};

pub fn calculateLayout(state: *types.GameState) UILayout {
    _ = state; // Parameter not used but kept for API compatibility
    // Use consistent dimensions - get fresh canvas size for layout calculation
    const size: CanvasSize = utils.get_canvas_size();

    // Update orientation based on current screen dimensions (not cached state)
    const aspect_ratio = @as(f32, @floatFromInt(size.w)) / @as(f32, @floatFromInt(size.h));
    const current_orientation: types.Orientation = if (aspect_ratio > 1.2) .Horizontal else .Vertical;

    // Basic sanity check for extremely small dimensions
    if (size.w < 100 or size.h < 100) {
        // For extremely small screens, just use vertical layout with no forced minimums
        return calculateVerticalLayoutWithSize(size);
    }

    // Use the live orientation for layout calculation to ensure consistency
    return switch (current_orientation) {
        .Vertical => calculateVerticalLayoutWithSize(size),
        .Horizontal => calculateHorizontalLayoutWithSize(size),
    };
}

fn calculateVerticalLayoutWithSize(size: CanvasSize) UILayout {
    const screen_width = size.w; // Use actual dimensions, no artificial minimums
    const screen_height = size.h; // Use actual dimensions, no artificial minimums
    const constants = getResponsiveConstants();

    // Calculate vertical center and spacing for main UI (using responsive constants)
    const ui_block_height = constants.medium_font + types.SMALL_SPACING + constants.large_font + types.ELEMENT_SPACING + @as(i32, @intFromFloat(constants.button_h)) + types.ELEMENT_SPACING + @as(i32, @intFromFloat(constants.confirm_h));
    var ui_start_y = @divTrunc((screen_height - ui_block_height), 2);
    ui_start_y = @max(ui_start_y, constants.margin);
    const progress_y = ui_start_y;
    var question_y = progress_y + constants.medium_font + types.SMALL_SPACING;
    question_y = @max(question_y, constants.margin);
    var buttons_y = question_y + constants.large_font + types.ELEMENT_SPACING;
    buttons_y = @max(buttons_y, constants.margin);
    var confirm_button_y = buttons_y + @as(i32, @intFromFloat(constants.button_h)) + types.ELEMENT_SPACING;
    confirm_button_y = @min(confirm_button_y, screen_height - @as(i32, @intFromFloat(constants.confirm_h)) - constants.margin);

    // Calculate button positions using responsive dimensions
    const total_button_width = constants.button_w * 2 + @as(f32, @floatFromInt(constants.button_gap));
    var buttons_x = @divTrunc((screen_width - @as(i32, @intFromFloat(total_button_width))), 2);
    buttons_x = @max(buttons_x, constants.margin);
    const button_rect_true = rl.Rectangle{ .x = @as(f32, @floatFromInt(buttons_x)), .y = @as(f32, @floatFromInt(buttons_y)), .width = constants.button_w, .height = constants.button_h };
    const button_rect_false = rl.Rectangle{ .x = @as(f32, @floatFromInt(buttons_x)) + constants.button_w + @as(f32, @floatFromInt(constants.button_gap)), .y = @as(f32, @floatFromInt(buttons_y)), .width = constants.button_w, .height = constants.button_h };
    var confirm_x = @divTrunc((screen_width - @as(i32, @intFromFloat(constants.confirm_w))), 2);
    confirm_x = @max(confirm_x, constants.margin);
    const confirm_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(confirm_x)), .y = @as(f32, @floatFromInt(confirm_button_y)), .width = constants.confirm_w, .height = constants.confirm_h };

    // Continue button for Finished state (positioned below score)
    var continue_button_y = question_y + types.MEDIUM_SPACING + constants.large_font + types.ELEMENT_SPACING;
    continue_button_y = @min(continue_button_y, screen_height - @as(i32, @intFromFloat(constants.confirm_h)) - constants.margin);
    var continue_x = @divTrunc((screen_width - @as(i32, @intFromFloat(constants.confirm_w))), 2);
    continue_x = @max(continue_x, constants.margin);
    const continue_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(continue_x)), .y = @as(f32, @floatFromInt(continue_button_y)), .width = constants.confirm_w, .height = constants.confirm_h };

    // Stack buttons vertically on the right side
    const button_stack_x = @as(f32, @floatFromInt(screen_width - types.BOTTOM_BUTTON_WIDTH - constants.margin));
    const button_gap = 8; // Gap between stacked buttons

    // COLOR button (top of stack)
    const randomize_btn_y = @as(f32, @floatFromInt(constants.margin));
    const randomize_btn = rl.Rectangle{ .x = button_stack_x, .y = randomize_btn_y, .width = types.BOTTOM_BUTTON_WIDTH, .height = types.BOTTOM_BUTTON_HEIGHT };

    // ANSWER button (middle of stack)
    const answer_btn_y = randomize_btn_y + types.BOTTOM_BUTTON_HEIGHT + button_gap;
    const answer_btn = rl.Rectangle{ .x = button_stack_x, .y = answer_btn_y, .width = types.BOTTOM_BUTTON_WIDTH, .height = types.BOTTOM_BUTTON_HEIGHT };

    // SUBMIT button (bottom of stack)
    const submit_btn_y = answer_btn_y + types.BOTTOM_BUTTON_HEIGHT + button_gap;
    const submit_btn = rl.Rectangle{ .x = button_stack_x, .y = submit_btn_y, .width = types.BOTTOM_BUTTON_WIDTH, .height = types.BOTTOM_BUTTON_HEIGHT };

    // Input box (centered vertically in main UI area)
    var input_box_x = @divTrunc((screen_width - types.INPUT_BOX_WIDTH), 2);
    input_box_x = @max(input_box_x, constants.margin);
    var input_box_y = question_y + types.MEDIUM_SPACING;
    input_box_y = @min(@max(input_box_y, constants.margin), screen_height - types.INPUT_BOX_HEIGHT - constants.margin);
    const input_box = rl.Rectangle{ .x = @as(f32, @floatFromInt(input_box_x)), .y = @as(f32, @floatFromInt(input_box_y)), .width = types.INPUT_BOX_WIDTH, .height = types.INPUT_BOX_HEIGHT };

    // Back button (top left corner)
    const back_btn = rl.Rectangle{ .x = @as(f32, @floatFromInt(constants.margin)), .y = @as(f32, @floatFromInt(constants.margin)), .width = 40, .height = 40 };

    return UILayout{
        .screen_width = screen_width,
        .screen_height = screen_height,
        .ui_block_height = ui_block_height,
        .ui_start_y = ui_start_y,
        .progress_y = progress_y,
        .question_y = question_y,
        .buttons_y = buttons_y,
        .confirm_button_y = confirm_button_y,
        .continue_button_y = continue_button_y,
        .button_rect_true = button_rect_true,
        .button_rect_false = button_rect_false,
        .confirm_rect = confirm_rect,
        .continue_rect = continue_rect,
        .randomize_btn = randomize_btn,
        .submit_btn = submit_btn,
        .answer_btn = answer_btn,
        .input_box = input_box,
        .back_btn = back_btn,
    };
}

fn calculateHorizontalLayoutWithSize(size: CanvasSize) UILayout {
    const screen_width = size.w; // Use actual dimensions, no artificial minimums
    const screen_height = size.h; // Use actual dimensions, no artificial minimums
    const constants = getResponsiveConstants();

    // Horizontal layout: Question area on left, controls on right
    const question_area_width = @divTrunc((screen_width * 3), 4);
    // Anchor menu panel to right edge
    const side_panel_x = @as(f32, @floatFromInt(screen_width - types.BOTTOM_BUTTON_WIDTH - constants.margin));

    // Calculate UI block height for proper vertical centering
    const calculated_ui_block_height = constants.medium_font + types.SMALL_SPACING + constants.large_font + types.ELEMENT_SPACING + @as(i32, @intFromFloat(constants.button_h)) + types.ELEMENT_SPACING + @as(i32, @intFromFloat(constants.confirm_h));
    var calculated_ui_start_y = @divTrunc((screen_height - calculated_ui_block_height), 2);
    calculated_ui_start_y = @max(calculated_ui_start_y, constants.margin);

    // Question area layout (left side) - now properly centered vertically
    const question_x = constants.margin;
    const question_y = calculated_ui_start_y;
    const progress_y = question_y;
    var question_text_y = progress_y + constants.medium_font + types.SMALL_SPACING;
    question_text_y = @max(question_text_y, constants.margin);

    // Answer buttons: side by side and centered in question area (same as vertical layout)
    var buttons_y = question_text_y + constants.large_font + types.ELEMENT_SPACING;
    buttons_y = @max(buttons_y, constants.margin);

    // Center the button pair within the actual question area (from question_x to side panel)
    const actual_question_width = @as(i32, @intFromFloat(side_panel_x)) - question_x;
    const total_button_width = constants.button_w * 2 + @as(f32, @floatFromInt(constants.button_gap));
    var buttons_x = question_x + @divTrunc((actual_question_width - @as(i32, @intFromFloat(total_button_width))), 2);
    buttons_x = @max(buttons_x, constants.margin);

    const button_rect_true = rl.Rectangle{ .x = @as(f32, @floatFromInt(buttons_x)), .y = @as(f32, @floatFromInt(buttons_y)), .width = constants.button_w, .height = constants.button_h };
    const button_rect_false = rl.Rectangle{ .x = @as(f32, @floatFromInt(buttons_x)) + constants.button_w + @as(f32, @floatFromInt(constants.button_gap)), .y = @as(f32, @floatFromInt(buttons_y)), .width = constants.button_w, .height = constants.button_h };

    // Confirm button below answer buttons, also centered
    var confirm_button_y = buttons_y + @as(i32, @intFromFloat(constants.button_h)) + types.ELEMENT_SPACING;
    confirm_button_y = @min(confirm_button_y, screen_height - @as(i32, @intFromFloat(constants.confirm_h)) - constants.margin);
    var confirm_x = question_x + @divTrunc((actual_question_width - @as(i32, @intFromFloat(constants.confirm_w))), 2);
    confirm_x = @max(confirm_x, constants.margin);
    const confirm_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(confirm_x)), .y = @as(f32, @floatFromInt(confirm_button_y)), .width = constants.confirm_w, .height = constants.confirm_h };

    // Continue button for finished state, centered in question area
    var continue_button_y = question_text_y + types.MEDIUM_SPACING + constants.large_font + types.ELEMENT_SPACING;
    continue_button_y = @min(continue_button_y, screen_height - @as(i32, @intFromFloat(constants.confirm_h)) - constants.margin);
    var continue_x = question_x + @divTrunc((actual_question_width - @as(i32, @intFromFloat(constants.confirm_w))), 2);
    continue_x = @max(continue_x, constants.margin);
    const continue_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(continue_x)), .y = @as(f32, @floatFromInt(continue_button_y)), .width = constants.confirm_w, .height = constants.confirm_h };

    // Side panel controls (right side) - stacked vertically
    const button_gap = 8; // Gap between stacked buttons

    // COLOR button (top of stack)
    const color_btn_y = @as(f32, @floatFromInt(constants.margin));
    const color_btn = rl.Rectangle{ .x = side_panel_x, .y = color_btn_y, .width = types.BOTTOM_BUTTON_WIDTH, .height = types.BOTTOM_BUTTON_HEIGHT };

    // ANSWER button (middle of stack)
    const answer_btn_y = color_btn_y + types.BOTTOM_BUTTON_HEIGHT + button_gap;
    const answer_btn = rl.Rectangle{ .x = side_panel_x, .y = answer_btn_y, .width = types.BOTTOM_BUTTON_WIDTH, .height = types.BOTTOM_BUTTON_HEIGHT };

    // SUBMIT button (bottom of stack)
    const submit_btn_y = answer_btn_y + types.BOTTOM_BUTTON_HEIGHT + button_gap;
    const submit_btn = rl.Rectangle{ .x = side_panel_x, .y = submit_btn_y, .width = types.BOTTOM_BUTTON_WIDTH, .height = types.BOTTOM_BUTTON_HEIGHT };

    // Input box (centered in question area)
    const input_box_x = question_x;
    var input_box_y = question_text_y + types.MEDIUM_SPACING;
    input_box_y = @min(@max(input_box_y, constants.margin), screen_height - types.INPUT_BOX_HEIGHT - constants.margin);
    const input_box = rl.Rectangle{ .x = @as(f32, @floatFromInt(input_box_x)), .y = @as(f32, @floatFromInt(input_box_y)), .width = @min(@as(f32, @floatFromInt(types.INPUT_BOX_WIDTH)), @as(f32, @floatFromInt(question_area_width)) - 2.0 * @as(f32, @floatFromInt(constants.margin))), .height = types.INPUT_BOX_HEIGHT };

    // Back button (top left corner)
    const back_btn = rl.Rectangle{ .x = @as(f32, @floatFromInt(constants.margin)), .y = @as(f32, @floatFromInt(constants.margin)), .width = 40, .height = 40 };

    // Calculate dummy values for compatibility
    const ui_block_height = confirm_button_y + @as(i32, @intFromFloat(constants.confirm_h)) - question_y;
    const ui_start_y = question_y;

    return UILayout{
        .screen_width = screen_width,
        .screen_height = screen_height,
        .ui_block_height = ui_block_height,
        .ui_start_y = ui_start_y,
        .progress_y = progress_y,
        .question_y = question_text_y,
        .buttons_y = buttons_y,
        .confirm_button_y = confirm_button_y,
        .continue_button_y = continue_button_y,
        .button_rect_true = button_rect_true,
        .button_rect_false = button_rect_false,
        .confirm_rect = confirm_rect,
        .continue_rect = continue_rect,
        .randomize_btn = color_btn,
        .submit_btn = submit_btn,
        .answer_btn = answer_btn,
        .input_box = input_box,
        .back_btn = back_btn,
    };
}

// --- Rendering Functions ---

pub fn drawLoadingScreen(state: *types.GameState, layout: UILayout) void {
    const constants = getResponsiveConstants();

    // Debug info for loading issues (only show during long loading)
    const current_time = std.time.timestamp();
    const loading_duration = current_time - state.loading_start_time;
    if (loading_duration > 5) { // Only show debug after 5 seconds
        const size = utils.get_canvas_size();
        var debug_buf: [128]u8 = undefined;
        const debug_text = std.fmt.bufPrintZ(&debug_buf, "Debug: {d}x{d} | Size: {s} | Time: {any}s", .{ size.w, size.h, if (size.w < 600) "Small" else "Large", loading_duration }) catch "Debug: ???";
        rl.drawText(debug_text, 10, 10, constants.small_font, state.fg_color);

        var state_buf: [64]u8 = undefined;
        const state_text = std.fmt.bufPrintZ(&state_buf, "State: {any} | Auth: {any}", .{ state.game_state, state.auth_initialized }) catch "State: ???";
        rl.drawText(state_text, 10, 10 + constants.small_font + 5, constants.small_font, state.fg_color);
    }

    // Loading screen
    const loading_width = rl.measureText(state.loading_message, constants.large_font);
    const loading_x = @divTrunc((layout.screen_width - loading_width), 2);
    rl.drawText(state.loading_message, loading_x, layout.question_y, constants.large_font, state.fg_color);

    // Show tap to continue after 8 seconds
    if (loading_duration > 8) {
        const help_text = "Tap anywhere to continue offline";
        const help_width = rl.measureText(help_text, constants.small_font);
        const help_x = @divTrunc((layout.screen_width - help_width), 2);
        rl.drawText(help_text, help_x, layout.question_y + types.MEDIUM_SPACING * 2, constants.small_font, state.fg_color);
    }

    // Simple loading animation (spinning dots)
    const time = rl.getTime();
    const dot_count = @as(usize, @intFromFloat(@mod(time, 3.0))) + 1;
    var loading_dots: [4]u8 = undefined;
    var i: usize = 0;
    while (i < dot_count and i < 3) : (i += 1) {
        loading_dots[i] = '.';
    }
    loading_dots[dot_count] = 0; // Null terminate after the dots
    const dots_text: [:0]const u8 = @ptrCast(loading_dots[0..dot_count :0]);
    const dots_width = rl.measureText(dots_text, constants.large_font);
    rl.drawText(dots_text, @divTrunc((layout.screen_width - dots_width), 2), layout.question_y + types.MEDIUM_SPACING, constants.large_font, state.fg_color);
}

// --- Text Wrapping Functions ---

fn drawWrappedText(text: [:0]const u8, x: i32, y: i32, max_width: i32, font_size: i32, color: rl.Color) i32 {
    // Much simpler approach: just break long text into chunks that fit
    const line_height = font_size + 4;
    var current_y = y;

    // If text fits on one line, just draw it
    const text_width = rl.measureText(text, font_size);
    if (text_width <= max_width) {
        rl.drawText(text, x, current_y, font_size, color);
        return line_height;
    }

    // Text is too long - try to break it into reasonable chunks
    // Simple approach: estimate characters per line and break there
    const avg_char_width = @divTrunc(text_width, @as(i32, @intCast(text.len)));
    const chars_per_line = if (avg_char_width > 0) @divTrunc(max_width, avg_char_width) else 20;

    var start_idx: usize = 0;
    while (start_idx < text.len) {
        const end_idx = @min(start_idx + @as(usize, @intCast(chars_per_line)), text.len);

        // Create a simple buffer for this chunk
        var chunk_buf: [128]u8 = undefined;
        const chunk_len = end_idx - start_idx;

        if (chunk_len < chunk_buf.len) {
            @memcpy(chunk_buf[0..chunk_len], text[start_idx..end_idx]);
            chunk_buf[chunk_len] = 0;

            const chunk: [:0]const u8 = @ptrCast(chunk_buf[0..chunk_len :0]);
            rl.drawText(chunk, x, current_y, font_size, color);
        }

        current_y += line_height;
        start_idx = end_idx;
    }

    return current_y - y; // Return total height used
}

// --- Utility Functions ---

pub fn shouldShowSubmitButton(state: *types.GameState) bool {
    // Gate submit button behind user progress and trust score
    // Allow submission if:
    // 1. User has completed at least one session
    // 2. User has a reasonable trust score (>= 0.6) OR has completed multiple sessions
    // 3. Not currently in the submitting screen (to avoid button overlap)
    const has_experience = state.sessions_completed >= 1;
    const has_good_trust = state.user_trust >= 0.6;
    const has_multiple_sessions = state.sessions_completed >= 2;
    const not_submitting = state.game_state != .Submitting;

    return has_experience and (has_good_trust or has_multiple_sessions) and not_submitting;
}

// --- Modular Drawing Functions ---

fn drawQuestionHeader(state: *types.GameState, layout: UILayout) void {
    const constants = getResponsiveConstants();
    const qnum = state.session.current + 1;
    var qstr_buf: [32]u8 = undefined;
    const qstr = std.fmt.bufPrintZ(&qstr_buf, "Question: {}", .{qnum}) catch "Question: ?";
    const qstr_width = rl.measureText(qstr, constants.medium_font);

    // Center the question header in the same area as the buttons
    // In horizontal mode, center within question area; in vertical mode, center across full width
    const size = utils.get_canvas_size();
    const aspect_ratio = @as(f32, @floatFromInt(size.w)) / @as(f32, @floatFromInt(size.h));
    const is_horizontal = aspect_ratio > 1.2;

    const header_x = if (is_horizontal)
        @as(i32, @intFromFloat(@divTrunc(layout.button_rect_true.x + layout.button_rect_false.x + layout.button_rect_false.width, 2))) - @divTrunc(qstr_width, 2)
    else
        @divTrunc((layout.screen_width - qstr_width), 2);

    rl.drawText(qstr, header_x, layout.progress_y, constants.medium_font, state.fg_color);
}

fn drawQuestionText(state: *types.GameState, layout: UILayout) void {
    const constants = getResponsiveConstants();

    // Safety check for mobile
    if (state.session.questions.len == 0 or state.session.current >= state.session.questions.len) {
        return;
    }

    const question = state.session.questions[state.session.current].question;

    // Check orientation for proper centering area
    const size = utils.get_canvas_size();
    const aspect_ratio = @as(f32, @floatFromInt(size.w)) / @as(f32, @floatFromInt(size.h));
    const is_horizontal = aspect_ratio > 1.2;

    // Check if text fits on one line
    const question_width = rl.measureText(question, constants.large_font);
    const max_width = layout.screen_width - 2 * constants.margin;

    if (question_width <= max_width) {
        // Text fits on one line - center it in the appropriate area
        const centered_x = if (is_horizontal)
            @divTrunc(@as(i32, @intFromFloat(layout.button_rect_true.x + layout.button_rect_false.x + layout.button_rect_false.width)), 2) - @divTrunc(question_width, 2)
        else
            @divTrunc((layout.screen_width - question_width), 2);
        rl.drawText(question, centered_x, layout.question_y, constants.large_font, state.fg_color);
    } else {
        // Text is too long - use wrapping (left-aligned in question area)
        const text_x = if (is_horizontal) constants.margin else constants.margin;
        _ = drawWrappedText(question, text_x, layout.question_y, max_width, constants.large_font, state.fg_color);
    }
}

fn drawAnswerButtons(state: *types.GameState, layout: UILayout) void {
    const constants = getResponsiveConstants();

    // Calculate responsive text positioning
    const true_text_width = rl.measureText("TRUE", constants.large_font);
    const false_text_width = rl.measureText("FALSE", constants.large_font);

    const true_text_x = @as(i32, @intFromFloat(layout.button_rect_true.x)) + @divTrunc(@as(i32, @intFromFloat(layout.button_rect_true.width)) - true_text_width, 2);
    const true_text_y = @as(i32, @intFromFloat(layout.button_rect_true.y)) + @divTrunc(@as(i32, @intFromFloat(layout.button_rect_true.height)) - constants.large_font, 2);

    const false_text_x = @as(i32, @intFromFloat(layout.button_rect_false.x)) + @divTrunc(@as(i32, @intFromFloat(layout.button_rect_false.width)) - false_text_width, 2);
    const false_text_y = @as(i32, @intFromFloat(layout.button_rect_false.y)) + @divTrunc(@as(i32, @intFromFloat(layout.button_rect_false.height)) - constants.large_font, 2);

    // Draw TRUE button
    rl.drawRectangleLinesEx(layout.button_rect_true, if (state.selected == true) types.THICK_BORDER else types.THIN_BORDER, if (state.selected == true) types.accent else state.fg_color);
    rl.drawText("TRUE", true_text_x, true_text_y, constants.large_font, state.fg_color);

    // Draw FALSE button
    rl.drawRectangleLinesEx(layout.button_rect_false, if (state.selected == false) types.THICK_BORDER else types.THIN_BORDER, if (state.selected == false) types.accent else state.fg_color);
    rl.drawText("FALSE", false_text_x, false_text_y, constants.large_font, state.fg_color);
}

fn drawConfirmButton(state: *types.GameState, layout: UILayout) void {
    const constants = getResponsiveConstants();
    const confirm_color = if (state.selected != null) types.accent else rl.Color{ .r = 180, .g = 180, .b = 180, .a = 255 };

    // Calculate responsive text positioning
    const confirm_text_width = rl.measureText("CONFIRM", constants.medium_font);
    const confirm_text_x = @as(i32, @intFromFloat(layout.confirm_rect.x)) + @divTrunc(@as(i32, @intFromFloat(layout.confirm_rect.width)) - confirm_text_width, 2);
    const confirm_text_y = layout.confirm_button_y + @divTrunc(@as(i32, @intFromFloat(layout.confirm_rect.height)) - constants.medium_font, 2);

    rl.drawRectangle(@as(i32, @intFromFloat(layout.confirm_rect.x)), layout.confirm_button_y, @as(i32, @intFromFloat(layout.confirm_rect.width)), @as(i32, @intFromFloat(layout.confirm_rect.height)), confirm_color);
    rl.drawText("CONFIRM", confirm_text_x, confirm_text_y, constants.medium_font, .white);
}

pub fn drawAnsweringScreen(state: *types.GameState, layout: UILayout) void {
    drawQuestionHeader(state, layout);

    drawQuestionText(state, layout);

    drawAnswerButtons(state, layout);

    drawConfirmButton(state, layout);
}

pub fn drawFinishedScreen(state: *types.GameState, layout: UILayout) void {
    const constants = getResponsiveConstants();
    const thank_width = rl.measureText("Thank you!", constants.large_font);
    rl.drawText("Thank you!", @divTrunc((layout.screen_width - thank_width), 2), layout.question_y, constants.large_font, state.fg_color);

    // Use a simpler approach to avoid WASM memory issues
    var score_buf: [32]u8 = undefined;
    const score_str = std.fmt.bufPrintZ(&score_buf, "Score: {}/7", .{state.session.correct}) catch "Score: ?";
    const score_width = rl.measureText(score_str, constants.large_font);
    rl.drawText(score_str, @divTrunc((layout.screen_width - score_width), 2), layout.question_y + types.MEDIUM_SPACING, constants.large_font, state.fg_color);

    // Continue button for Finished state
    const continue_text_width = rl.measureText("CONTINUE", constants.medium_font);
    const continue_text_x = @as(i32, @intFromFloat(layout.continue_rect.x)) + @divTrunc(@as(i32, @intFromFloat(layout.continue_rect.width)) - continue_text_width, 2);
    const continue_text_y = layout.continue_button_y + @divTrunc(@as(i32, @intFromFloat(layout.continue_rect.height)) - constants.medium_font, 2);

    rl.drawRectangle(@as(i32, @intFromFloat(layout.continue_rect.x)), layout.continue_button_y, @as(i32, @intFromFloat(layout.continue_rect.width)), @as(i32, @intFromFloat(layout.continue_rect.height)), types.accent);
    rl.drawText("CONTINUE", continue_text_x, continue_text_y, constants.medium_font, .white);
}

pub fn drawSubmittingScreen(state: *types.GameState, layout: UILayout) void {
    const constants = getResponsiveConstants();

    // Title
    const title_text = "Submit your own question!";
    const title_width = rl.measureText(title_text, constants.large_font);
    rl.drawText(title_text, @divTrunc((layout.screen_width - title_width), 2), layout.question_y, constants.large_font, state.fg_color);

    // Instructions
    const instructions = "Ask a true/false question for other players";
    const instructions_width = rl.measureText(instructions, constants.small_font);
    rl.drawText(instructions, @divTrunc((layout.screen_width - instructions_width), 2), layout.question_y + constants.large_font + 10, constants.small_font, state.fg_color);

    // Draw input box
    const input_box_color = if (state.input_active) types.accent else state.fg_color;
    rl.drawRectangleLinesEx(layout.input_box, types.INPUT_BORDER, input_box_color);

    const input_text = if (state.input_len > 0) @as([:0]const u8, @ptrCast(&state.input_buffer)) else "Type your question here...";
    const text_color = if (state.input_len > 0) state.fg_color else rl.Color{ .r = 150, .g = 150, .b = 150, .a = 255 };
    rl.drawText(input_text, @as(i32, @intFromFloat(layout.input_box.x)) + types.TEXT_PADDING, @as(i32, @intFromFloat(layout.input_box.y)) + types.TEXT_PADDING, constants.small_font, text_color);

    // Draw cursor if input is active
    if (state.input_active and (@mod(rl.getTime() * 2.0, 2.0) < 1.0)) {
        const cursor_x = @as(i32, @intFromFloat(layout.input_box.x)) + types.TEXT_PADDING + rl.measureText(input_text, constants.small_font);
        rl.drawRectangle(cursor_x, @as(i32, @intFromFloat(layout.input_box.y)) + types.TEXT_PADDING, types.CURSOR_WIDTH, types.CURSOR_HEIGHT, state.fg_color);
    }

    // Submit button for the question (only show if there's input)
    if (state.input_len > 5) { // Minimum question length
        const submit_question_y = @as(i32, @intFromFloat(layout.input_box.y)) + types.INPUT_BOX_HEIGHT + 20;
        const submit_question_rect = rl.Rectangle{ .x = layout.input_box.x, .y = @as(f32, @floatFromInt(submit_question_y)), .width = constants.confirm_w, .height = constants.confirm_h };

        // Calculate responsive text positioning
        const send_text_width = rl.measureText("SEND QUESTION", constants.medium_font);
        const send_text_x = @as(i32, @intFromFloat(submit_question_rect.x)) + @divTrunc(@as(i32, @intFromFloat(submit_question_rect.width)) - send_text_width, 2);
        const send_text_y = submit_question_y + @divTrunc(@as(i32, @intFromFloat(submit_question_rect.height)) - constants.medium_font, 2);

        rl.drawRectangleRec(submit_question_rect, types.accent);
        rl.drawText("SEND QUESTION", send_text_x, send_text_y, constants.medium_font, .white);
    }

    // Back arrow button (top left corner)
    rl.drawRectangleLinesEx(layout.back_btn, 2, state.fg_color);

    // Draw a simple left arrow
    const arrow_center_x = @as(i32, @intFromFloat(layout.back_btn.x)) + 20;
    const arrow_center_y = @as(i32, @intFromFloat(layout.back_btn.y)) + 20;

    // Arrow lines (simple ASCII-style arrow)
    rl.drawText("<", arrow_center_x - 8, arrow_center_y - 12, constants.large_font, state.fg_color);
}

pub fn drawAlwaysVisibleUI(state: *types.GameState, layout: UILayout) void {
    const constants = getResponsiveConstants();

    // Check if we need to draw the side panel (horizontal mode)
    const size = utils.get_canvas_size();
    const aspect_ratio = @as(f32, @floatFromInt(size.w)) / @as(f32, @floatFromInt(size.h));
    const is_horizontal = aspect_ratio > 1.2;

    if (is_horizontal) {
        // Draw classic RPG-style vertical pillar separator (full height)
        const base_pillar_width = 24;
        const pillar_x = layout.randomize_btn.x - @as(f32, @floatFromInt(base_pillar_width + 20));

        // Capital and base dimensions - much more prominent
        const capital_height = 28; // Increased from 16
        const base_height = 24; // Increased from 12
        const capital_width = base_pillar_width + 16; // Much wider capital (was +8)
        const capital_x = pillar_x - 8; // Center the wider capital

        // Draw multi-tiered base (classical stepped base)

        // Base tier 1 (bottom, widest)
        const base_tier1_height = 10;
        const base_tier1_width = capital_width + 4; // Even wider than capital
        const base_tier1_x = capital_x - 2;
        rl.drawRectangle(@as(i32, @intFromFloat(base_tier1_x)), layout.screen_height - base_tier1_height, @as(i32, @intFromFloat(base_tier1_width)), base_tier1_height, rl.Color{ .r = state.fg_color.r, .g = state.fg_color.g, .b = state.fg_color.b, .a = 180 });
        // Base tier 1 highlight
        rl.drawRectangle(@as(i32, @intFromFloat(base_tier1_x)), layout.screen_height - base_tier1_height, @as(i32, @intFromFloat(base_tier1_width)), 2, rl.Color{ .r = @min(255, state.fg_color.r + 60), .g = @min(255, state.fg_color.g + 60), .b = @min(255, state.fg_color.b + 60), .a = 150 });

        // Base tier 2 (middle)
        const base_tier2_height = 8;
        const base_tier2_y = layout.screen_height - base_tier1_height - base_tier2_height;
        rl.drawRectangle(@as(i32, @intFromFloat(capital_x)), base_tier2_y, @as(i32, @intFromFloat(capital_width)), base_tier2_height, rl.Color{ .r = state.fg_color.r, .g = state.fg_color.g, .b = state.fg_color.b, .a = 170 });
        rl.drawRectangle(@as(i32, @intFromFloat(capital_x)), base_tier2_y, @as(i32, @intFromFloat(capital_width)), 2, rl.Color{ .r = @min(255, state.fg_color.r + 50), .g = @min(255, state.fg_color.g + 50), .b = @min(255, state.fg_color.b + 50), .a = 140 });

        // Base tier 3 (top, connects to pillar)
        const base_tier3_height = 6;
        const base_tier3_y = layout.screen_height - base_tier1_height - base_tier2_height - base_tier3_height;
        rl.drawRectangle(@as(i32, @intFromFloat(pillar_x)), base_tier3_y, base_pillar_width, base_tier3_height, rl.Color{ .r = state.fg_color.r, .g = state.fg_color.g, .b = state.fg_color.b, .a = 160 });
        rl.drawRectangle(@as(i32, @intFromFloat(pillar_x)), base_tier3_y, base_pillar_width, 2, rl.Color{ .r = @min(255, state.fg_color.r + 40), .g = @min(255, state.fg_color.g + 40), .b = @min(255, state.fg_color.b + 40), .a = 130 });

        // Draw elaborate capital (classical Corinthian-style)
        // Capital tier 1 (top, abacus - widest part)
        const cap_tier1_height = 8;
        const cap_tier1_width = capital_width + 6; // Widest part at top
        const cap_tier1_x = capital_x - 3;
        rl.drawRectangle(@as(i32, @intFromFloat(cap_tier1_x)), 0, @as(i32, @intFromFloat(cap_tier1_width)), cap_tier1_height, rl.Color{ .r = state.fg_color.r, .g = state.fg_color.g, .b = state.fg_color.b, .a = 180 });
        rl.drawRectangle(@as(i32, @intFromFloat(cap_tier1_x)), 0, @as(i32, @intFromFloat(cap_tier1_width)), 2, rl.Color{ .r = @min(255, state.fg_color.r + 60), .g = @min(255, state.fg_color.g + 60), .b = @min(255, state.fg_color.b + 60), .a = 150 });

        // Capital tier 2 (middle, decorative body)
        const cap_tier2_height = 12;
        const cap_tier2_y = cap_tier1_height;
        rl.drawRectangle(@as(i32, @intFromFloat(capital_x)), cap_tier2_y, @as(i32, @intFromFloat(capital_width)), cap_tier2_height, rl.Color{ .r = state.fg_color.r, .g = state.fg_color.g, .b = state.fg_color.b, .a = 170 });
        rl.drawRectangle(@as(i32, @intFromFloat(capital_x)), cap_tier2_y, @as(i32, @intFromFloat(capital_width)), 2, rl.Color{ .r = @min(255, state.fg_color.r + 50), .g = @min(255, state.fg_color.g + 50), .b = @min(255, state.fg_color.b + 50), .a = 140 });
        rl.drawRectangle(@as(i32, @intFromFloat(capital_x)), cap_tier2_y + cap_tier2_height - 2, @as(i32, @intFromFloat(capital_width)), 2, rl.Color{ .r = state.fg_color.r / 2, .g = state.fg_color.g / 2, .b = state.fg_color.b / 2, .a = 140 });

        // Capital tier 3 (bottom, connects to pillar shaft)
        const cap_tier3_height = 8;
        const cap_tier3_y = cap_tier2_y + cap_tier2_height;
        rl.drawRectangle(@as(i32, @intFromFloat(pillar_x)), cap_tier3_y, base_pillar_width, cap_tier3_height, rl.Color{ .r = state.fg_color.r, .g = state.fg_color.g, .b = state.fg_color.b, .a = 160 });
        rl.drawRectangle(@as(i32, @intFromFloat(pillar_x)), cap_tier3_y + cap_tier3_height - 2, base_pillar_width, 2, rl.Color{ .r = state.fg_color.r / 2, .g = state.fg_color.g / 2, .b = state.fg_color.b / 2, .a = 140 });

        // Add decorative molding lines on capital
        var molding_y: i32 = cap_tier2_y + 3;
        while (molding_y < cap_tier2_y + cap_tier2_height - 3) : (molding_y += 3) {
            rl.drawRectangle(@as(i32, @intFromFloat(capital_x)) + 2, molding_y, @as(i32, @intFromFloat(capital_width)) - 4, 1, rl.Color{ .r = state.fg_color.r / 3, .g = state.fg_color.g / 3, .b = state.fg_color.b / 3, .a = 100 });
        }

        // Draw main pillar body with tapered shape and gradient
        const pillar_start_y = capital_height;
        const pillar_end_y = layout.screen_height - base_height;
        const pillar_body_height = pillar_end_y - pillar_start_y;

        // Draw pillar in segments for gradient and tapering effect
        const segment_height = 4;
        var segment_y: i32 = pillar_start_y;
        while (segment_y < pillar_end_y) : (segment_y += segment_height) {
            const progress = @as(f32, @floatFromInt(segment_y - pillar_start_y)) / @as(f32, @floatFromInt(pillar_body_height));

            // Tapered width (narrower at top and bottom)
            const taper_factor = 1.0 - (@abs(progress - 0.5) * 0.3); // Max taper of 30%
            const current_width = @as(i32, @intFromFloat(@as(f32, @floatFromInt(base_pillar_width)) * taper_factor));
            const current_x = pillar_x + @as(f32, @floatFromInt(base_pillar_width - current_width)) / 2.0;

            // Gradient shading (lighter at top, darker at bottom)
            const light_factor = 1.0 - (progress * 0.4); // 40% darkening from top to bottom
            const segment_alpha = @as(u8, @intFromFloat(140 * light_factor));

            const actual_segment_height = @min(segment_height, pillar_end_y - segment_y);
            rl.drawRectangle(@as(i32, @intFromFloat(current_x)), segment_y, current_width, actual_segment_height, rl.Color{ .r = state.fg_color.r, .g = state.fg_color.g, .b = state.fg_color.b, .a = segment_alpha });

            // Tapered highlights and shadows
            const highlight_width = @divTrunc(@max(2, current_width), 8);
            const shadow_width = @divTrunc(@max(2, current_width), 8);

            // Left highlight (lighter) with gradient
            const highlight_alpha = @as(u8, @intFromFloat(180 * light_factor));
            rl.drawRectangle(@as(i32, @intFromFloat(current_x)), segment_y, highlight_width, actual_segment_height, rl.Color{ .r = @min(255, state.fg_color.r + 70), .g = @min(255, state.fg_color.g + 70), .b = @min(255, state.fg_color.b + 70), .a = highlight_alpha });

            // Right shadow (darker) with gradient
            const shadow_alpha = @as(u8, @intFromFloat(180 * (1.0 - light_factor * 0.5))); // Shadows get stronger toward bottom
            rl.drawRectangle(@as(i32, @intFromFloat(current_x)) + current_width - shadow_width, segment_y, shadow_width, actual_segment_height, rl.Color{ .r = state.fg_color.r / 2, .g = state.fg_color.g / 2, .b = state.fg_color.b / 2, .a = shadow_alpha });
        }

        // Draw multiple overlapping spiral patterns for rich carved stone texture
        const spiral_center_x = pillar_x + @as(f32, @floatFromInt(base_pillar_width / 2));
        const spiral_radius = @as(f32, @floatFromInt(base_pillar_width / 3));
        const spiral_step = 1.5; // Finer vertical step for smoother spirals
        const spiral_repeat = 14.0; // Slightly tighter vertical repeat distance

        // Draw multiple spirals with different phase offsets - increased density
        const num_spirals = 5; // Increased from 3 to 5 for richer texture
        var spiral_index: i32 = 0;
        while (spiral_index < num_spirals) : (spiral_index += 1) {
            const phase_offset = @as(f32, @floatFromInt(spiral_index)) * (2.0 * std.math.pi / @as(f32, @floatFromInt(num_spirals))); // Evenly distribute spirals

            var y: f32 = @as(f32, @floatFromInt(pillar_start_y));
            while (y < @as(f32, @floatFromInt(pillar_end_y))) : (y += spiral_step) {
                // Calculate spiral angle based on height with phase offset and repeat
                const base_angle = (y / spiral_repeat) * 2.0 * std.math.pi + phase_offset;
                const angle = base_angle * 0.8; // Controls spiral tightness

                // Calculate spiral positions
                const spiral_x = spiral_center_x + @cos(angle) * spiral_radius;
                const spiral_inner_x = spiral_center_x + @cos(angle) * (spiral_radius * 0.7);

                // Create depth effect with varying opacity and size
                const depth_factor = (@sin(angle + phase_offset) + 1.0) / 2.0; // 0.0 to 1.0
                const spiral_alpha = @as(u8, @intFromFloat(60 + depth_factor * 100)); // 60 to 160 (reduced for overlapping)

                // Vary the spiral intensity based on which spiral this is
                const spiral_intensity = 1.0 - (@as(f32, @floatFromInt(spiral_index)) * 0.2); // First spiral strongest
                const final_alpha = @as(u8, @intFromFloat(@as(f32, @floatFromInt(spiral_alpha)) * spiral_intensity));

                // Outer spiral line (darker) - size varies with depth
                const outer_size: i32 = if (depth_factor > 0.5) 2 else 1;
                rl.drawRectangle(@as(i32, @intFromFloat(spiral_x)), @as(i32, @intFromFloat(y)), outer_size, outer_size, rl.Color{ .r = state.fg_color.r / 4, .g = state.fg_color.g / 4, .b = state.fg_color.b / 4, .a = final_alpha });

                // Inner spiral line (lighter, for depth) - only draw for prominent parts
                if (depth_factor > 0.3) {
                    rl.drawRectangle(@as(i32, @intFromFloat(spiral_inner_x)), @as(i32, @intFromFloat(y)), 1, 1, rl.Color{ .r = @min(255, state.fg_color.r + 30), .g = @min(255, state.fg_color.g + 30), .b = @min(255, state.fg_color.b + 30), .a = final_alpha / 3 });
                }
            }
        }
    }

    // COLOR button (top of stack)
    rl.drawRectangleRec(layout.randomize_btn, state.fg_color);
    const color_text = "COLOR";
    const color_font_size = constants.small_font;
    const color_text_width = rl.measureText(color_text, color_font_size);
    const color_text_x = @as(i32, @intFromFloat(layout.randomize_btn.x)) + @divTrunc((types.BOTTOM_BUTTON_WIDTH - color_text_width), 2);
    const color_text_y = @as(i32, @intFromFloat(layout.randomize_btn.y)) + @divTrunc((types.BOTTOM_BUTTON_HEIGHT - color_font_size), 2);
    rl.drawText(color_text, color_text_x, color_text_y, color_font_size, state.bg_color);

    // SUBMIT button (bottom of stack, only for qualified users)
    if (shouldShowSubmitButton(state)) {
        rl.drawRectangleRec(layout.submit_btn, state.fg_color);
        const submit_text = "SUBMIT";
        const submit_text_width = rl.measureText(submit_text, constants.small_font);
        const submit_text_x = @as(i32, @intFromFloat(layout.submit_btn.x)) + @divTrunc((types.BOTTOM_BUTTON_WIDTH - submit_text_width), 2);
        const submit_text_y = @as(i32, @intFromFloat(layout.submit_btn.y)) + @divTrunc((types.BOTTOM_BUTTON_HEIGHT - constants.small_font), 2);
        rl.drawText(submit_text, submit_text_x, submit_text_y, constants.small_font, state.bg_color);
    }

    // ANSWER button (middle of stack)
    rl.drawRectangleRec(layout.answer_btn, state.fg_color);
    const answer_text = "ANSWER";
    const answer_text_width = rl.measureText(answer_text, constants.small_font);
    const answer_text_x = @as(i32, @intFromFloat(layout.answer_btn.x)) + @divTrunc((types.BOTTOM_BUTTON_WIDTH - answer_text_width), 2);
    const answer_text_y = @as(i32, @intFromFloat(layout.answer_btn.y)) + @divTrunc((types.BOTTOM_BUTTON_HEIGHT - constants.small_font), 2);
    rl.drawText(answer_text, answer_text_x, answer_text_y, constants.small_font, state.bg_color);

    // Draw tags for high-trust users during answering
    if (state.user_trust >= 0.85 and state.game_state == .Answering) {
        for (state.session.questions[state.session.current].tags) |tag| {
            _ = tag;
            // Optionally draw tags
        }
    }
}

// --- Main Draw Function ---

pub fn draw(state: *types.GameState) void {
    // Ensure raylib's canvas size matches the browser canvas size every frame
    utils.updateCanvasSize();

    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(state.bg_color);

    const layout = calculateLayout(state);

    // Draw state-specific UI
    switch (state.game_state) {
        .Loading, .Authenticating => {
            drawLoadingScreen(state, layout);
        },
        .Answering => {
            drawAnsweringScreen(state, layout);
        },
        .Finished => {
            drawFinishedScreen(state, layout);
        },
        .Submitting => {
            drawSubmittingScreen(state, layout);
        },
    }

    // Always-visible UI elements
    drawAlwaysVisibleUI(state, layout);
}
