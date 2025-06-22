const std = @import("std");
const rl = @import("raylib");
const types = @import("types.zig");
const utils = @import("utils.zig");

// --- UI Layout Calculation Functions ---

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
};

pub fn calculateLayout(state: *types.GameState) UILayout {
    return switch (state.orientation) {
        .Vertical => calculateVerticalLayout(),
        .Horizontal => calculateHorizontalLayout(),
    };
}

fn calculateVerticalLayout() UILayout {
    const size = utils.get_canvas_size();
    const screen_width = size.w;
    const screen_height = size.h;

    // Calculate vertical center and spacing for main UI
    const ui_block_height = types.MEDIUM_FONT_SIZE + types.SMALL_SPACING + types.LARGE_FONT_SIZE + types.ELEMENT_SPACING + types.button_h + types.ELEMENT_SPACING + types.confirm_h;
    const ui_start_y = @divTrunc((screen_height - ui_block_height), 2);
    const progress_y = ui_start_y;
    const question_y = progress_y + types.MEDIUM_FONT_SIZE + types.SMALL_SPACING;
    const buttons_y = question_y + types.LARGE_FONT_SIZE + types.ELEMENT_SPACING;
    const confirm_button_y = buttons_y + types.button_h + types.ELEMENT_SPACING;

    // Calculate button positions
    const total_button_width = types.button_w * 2 + types.BUTTON_GAP;
    const buttons_x = @as(f32, @floatFromInt(@divTrunc((screen_width - total_button_width), 2)));
    const button_rect_true = rl.Rectangle{ .x = buttons_x, .y = @as(f32, @floatFromInt(buttons_y)), .width = types.button_w, .height = types.button_h };
    const button_rect_false = rl.Rectangle{ .x = buttons_x + types.button_w + types.BUTTON_GAP, .y = @as(f32, @floatFromInt(buttons_y)), .width = types.button_w, .height = types.button_h };
    const confirm_x = @as(f32, @floatFromInt(@divTrunc((screen_width - types.confirm_w), 2)));
    const confirm_rect = rl.Rectangle{ .x = confirm_x, .y = @as(f32, @floatFromInt(confirm_button_y)), .width = types.confirm_w, .height = types.confirm_h };

    // Continue button for Finished state (positioned below score)
    const continue_button_y = question_y + types.MEDIUM_SPACING + types.LARGE_FONT_SIZE + types.ELEMENT_SPACING;
    const continue_x = @as(f32, @floatFromInt(@divTrunc((screen_width - types.confirm_w), 2)));
    const continue_rect = rl.Rectangle{ .x = continue_x, .y = @as(f32, @floatFromInt(continue_button_y)), .width = types.confirm_w, .height = types.confirm_h };

    // COLOR button in top right
    const randomize_btn_x = @as(f32, @floatFromInt(screen_width - types.COLOR_BUTTON_WIDTH - types.MARGIN));
    const randomize_btn_y = @as(f32, @floatFromInt(types.MARGIN));
    const randomize_btn = rl.Rectangle{ .x = randomize_btn_x, .y = randomize_btn_y, .width = types.COLOR_BUTTON_WIDTH, .height = types.COLOR_BUTTON_HEIGHT };

    // SUBMIT and ANSWER buttons in bottom right
    const bottom_btn_y = @as(f32, @floatFromInt(screen_height - types.BOTTOM_BUTTON_HEIGHT - types.MARGIN));
    const answer_btn_x = @as(f32, @floatFromInt(screen_width - types.BOTTOM_BUTTON_WIDTH - types.MARGIN));
    const submit_btn_x = answer_btn_x - types.BOTTOM_BUTTON_WIDTH - types.BOTTOM_BUTTON_GAP;
    const submit_btn = rl.Rectangle{ .x = submit_btn_x, .y = bottom_btn_y, .width = types.BOTTOM_BUTTON_WIDTH, .height = types.BOTTOM_BUTTON_HEIGHT };
    const answer_btn = rl.Rectangle{ .x = answer_btn_x, .y = bottom_btn_y, .width = types.BOTTOM_BUTTON_WIDTH, .height = types.BOTTOM_BUTTON_HEIGHT };

    // Input box (centered vertically in main UI area)
    const input_box_x = @as(f32, @floatFromInt(@divTrunc((screen_width - types.INPUT_BOX_WIDTH), 2)));
    const input_box_y = @as(f32, @floatFromInt(question_y + types.MEDIUM_SPACING));
    const input_box = rl.Rectangle{ .x = input_box_x, .y = input_box_y, .width = types.INPUT_BOX_WIDTH, .height = types.INPUT_BOX_HEIGHT };

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
    };
}

fn calculateHorizontalLayout() UILayout {
    const size = utils.get_canvas_size();
    const screen_width = size.w;
    const screen_height = size.h;

    // Horizontal layout: Question area on left, controls on right
    const question_area_width = @divTrunc((screen_width * 2), 3);
    const side_panel_x = question_area_width + types.MARGIN;

    // Question area layout (left side)
    const question_x = types.MARGIN;
    const question_y = types.MARGIN;
    const progress_y = question_y;
    const question_text_y = progress_y + types.MEDIUM_FONT_SIZE + types.SMALL_SPACING;

    // Answer buttons: vertical stack in question area
    const buttons_y = question_text_y + types.LARGE_FONT_SIZE + types.ELEMENT_SPACING;
    const button_spacing = 20;
    const button_rect_true = rl.Rectangle{ .x = @as(f32, @floatFromInt(question_x)), .y = @as(f32, @floatFromInt(buttons_y)), .width = types.button_w, .height = types.button_h };
    const button_rect_false = rl.Rectangle{ .x = @as(f32, @floatFromInt(question_x)), .y = @as(f32, @floatFromInt(buttons_y + @as(i32, @intFromFloat(types.button_h)) + button_spacing)), .width = types.button_w, .height = types.button_h };

    // Confirm button below answer buttons
    const confirm_button_y = buttons_y + @as(i32, @intFromFloat(types.button_h)) * 2 + button_spacing * 2 + types.ELEMENT_SPACING;
    const confirm_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(question_x)), .y = @as(f32, @floatFromInt(confirm_button_y)), .width = types.confirm_w, .height = types.confirm_h };

    // Continue button for finished state
    const continue_button_y = question_text_y + types.MEDIUM_SPACING + types.LARGE_FONT_SIZE + types.ELEMENT_SPACING;
    const continue_rect = rl.Rectangle{ .x = @as(f32, @floatFromInt(question_x)), .y = @as(f32, @floatFromInt(continue_button_y)), .width = types.confirm_w, .height = types.confirm_h };

    // Side panel controls (right side)
    const color_btn = rl.Rectangle{ .x = @as(f32, @floatFromInt(side_panel_x)), .y = @as(f32, @floatFromInt(types.MARGIN)), .width = types.COLOR_BUTTON_WIDTH, .height = types.COLOR_BUTTON_HEIGHT };

    // Bottom buttons in side panel
    const bottom_btn_y = screen_height - types.BOTTOM_BUTTON_HEIGHT - types.MARGIN;
    const answer_btn = rl.Rectangle{ .x = @as(f32, @floatFromInt(side_panel_x)), .y = @as(f32, @floatFromInt(bottom_btn_y)), .width = types.BOTTOM_BUTTON_WIDTH, .height = types.BOTTOM_BUTTON_HEIGHT };
    const submit_btn = rl.Rectangle{ .x = @as(f32, @floatFromInt(side_panel_x)), .y = @as(f32, @floatFromInt(bottom_btn_y - types.BOTTOM_BUTTON_HEIGHT - types.BOTTOM_BUTTON_GAP)), .width = types.BOTTOM_BUTTON_WIDTH, .height = types.BOTTOM_BUTTON_HEIGHT };

    // Input box (centered in question area)
    const input_box_x = @as(f32, @floatFromInt(question_x));
    const input_box_y = @as(f32, @floatFromInt(question_text_y + types.MEDIUM_SPACING));
    const input_box = rl.Rectangle{ .x = input_box_x, .y = input_box_y, .width = @min(types.INPUT_BOX_WIDTH, @as(f32, @floatFromInt(question_area_width)) - 2 * types.MARGIN), .height = types.INPUT_BOX_HEIGHT };

    // Calculate dummy values for compatibility
    const ui_block_height = confirm_button_y + @as(i32, @intFromFloat(types.confirm_h)) - question_y;
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
    };
}

// --- Rendering Functions ---

pub fn drawLoadingScreen(state: *types.GameState, layout: UILayout) void {
    // Loading screen
    const loading_width = rl.measureText(state.loading_message, types.LARGE_FONT_SIZE);
    rl.drawText(state.loading_message, @divTrunc((layout.screen_width - loading_width), 2), layout.question_y, types.LARGE_FONT_SIZE, state.fg_color);

    // Simple loading animation (spinning dots)
    const time = rl.getTime();
    const dot_count = @as(usize, @intFromFloat(@mod(time, 3.0))) + 1;
    var loading_dots: [4]u8 = undefined;
    var i: usize = 0;
    while (i < dot_count and i < 3) : (i += 1) {
        loading_dots[i] = '.';
    }
    loading_dots[dot_count] = 0;
    const dots_text: [:0]const u8 = @ptrCast(loading_dots[0..dot_count :0]);
    const dots_width = rl.measureText(dots_text, types.LARGE_FONT_SIZE);
    rl.drawText(dots_text, @divTrunc((layout.screen_width - dots_width), 2), layout.question_y + types.MEDIUM_SPACING, types.LARGE_FONT_SIZE, state.fg_color);
}

// --- Modular Drawing Functions ---

fn drawQuestionHeader(state: *types.GameState, layout: UILayout) void {
    const qnum = state.session.current + 1;
    var qstr_buf: [32]u8 = undefined;
    const qstr = std.fmt.bufPrintZ(&qstr_buf, "Question: {}", .{qnum}) catch "Question: ?";
    const qstr_width = rl.measureText(qstr, types.MEDIUM_FONT_SIZE);
    rl.drawText(qstr, @divTrunc((layout.screen_width - qstr_width), 2), layout.progress_y, types.MEDIUM_FONT_SIZE, state.fg_color);
}

fn drawQuestionText(state: *types.GameState, layout: UILayout) void {
    const question = state.session.questions[state.session.current].question;
    const question_width = rl.measureText(question, types.LARGE_FONT_SIZE);
    rl.drawText(question, @divTrunc((layout.screen_width - question_width), 2), layout.question_y, types.LARGE_FONT_SIZE, state.fg_color);
}

fn drawAnswerButtons(state: *types.GameState, layout: UILayout) void {
    // Draw TRUE button
    rl.drawRectangleLinesEx(layout.button_rect_true, if (state.selected == true) types.THICK_BORDER else types.THIN_BORDER, if (state.selected == true) types.accent else state.fg_color);
    rl.drawText("TRUE", @as(i32, @intFromFloat(layout.button_rect_true.x)) + types.BUTTON_TEXT_OFFSET_X, @as(i32, @intFromFloat(layout.button_rect_true.y)) + types.BUTTON_TEXT_OFFSET_Y, types.LARGE_FONT_SIZE, state.fg_color);

    // Draw FALSE button
    rl.drawRectangleLinesEx(layout.button_rect_false, if (state.selected == false) types.THICK_BORDER else types.THIN_BORDER, if (state.selected == false) types.accent else state.fg_color);
    rl.drawText("FALSE", @as(i32, @intFromFloat(layout.button_rect_false.x)) + types.BUTTON_TEXT_OFFSET_X, @as(i32, @intFromFloat(layout.button_rect_false.y)) + types.BUTTON_TEXT_OFFSET_Y, types.LARGE_FONT_SIZE, state.fg_color);
}

fn drawConfirmButton(state: *types.GameState, layout: UILayout) void {
    const confirm_color = if (state.selected != null) types.accent else rl.Color{ .r = 180, .g = 180, .b = 180, .a = 255 };
    rl.drawRectangle(@as(i32, @intFromFloat(layout.confirm_rect.x)), layout.confirm_button_y, @as(i32, @intFromFloat(types.confirm_w)), @as(i32, @intFromFloat(types.confirm_h)), confirm_color);
    rl.drawText("CONFIRM", @as(i32, @intFromFloat(layout.confirm_rect.x)) + types.CONFIRM_TEXT_OFFSET_X, layout.confirm_button_y + types.CONFIRM_TEXT_OFFSET_Y, types.MEDIUM_FONT_SIZE, .white);
}

pub fn drawAnsweringScreen(state: *types.GameState, layout: UILayout) void {
    drawQuestionHeader(state, layout);
    drawQuestionText(state, layout);
    drawAnswerButtons(state, layout);
    drawConfirmButton(state, layout);
}

pub fn drawFinishedScreen(state: *types.GameState, layout: UILayout) void {
    const thank_width = rl.measureText("Thank you!", types.LARGE_FONT_SIZE);
    rl.drawText("Thank you!", @divTrunc((layout.screen_width - thank_width), 2), layout.question_y, types.LARGE_FONT_SIZE, state.fg_color);

    // Use a simpler approach to avoid WASM memory issues
    var score_buf: [32]u8 = undefined;
    const score_str = std.fmt.bufPrintZ(&score_buf, "Score: {}/7", .{state.session.correct}) catch "Score: ?";
    const score_width = rl.measureText(score_str, types.LARGE_FONT_SIZE);
    rl.drawText(score_str, @divTrunc((layout.screen_width - score_width), 2), layout.question_y + types.MEDIUM_SPACING, types.LARGE_FONT_SIZE, state.fg_color);

    // Continue button for Finished state
    rl.drawRectangle(@as(i32, @intFromFloat(layout.continue_rect.x)), layout.continue_button_y, @as(i32, @intFromFloat(types.confirm_w)), @as(i32, @intFromFloat(types.confirm_h)), types.accent);
    rl.drawText("CONTINUE", @as(i32, @intFromFloat(layout.continue_rect.x)) + types.CONFIRM_TEXT_OFFSET_X, layout.continue_button_y + types.CONFIRM_TEXT_OFFSET_Y, types.MEDIUM_FONT_SIZE, .white);
}

pub fn drawSubmittingScreen(state: *types.GameState, layout: UILayout) void {
    const submit_width = rl.measureText("Submit your own question!", types.LARGE_FONT_SIZE);
    rl.drawText("Submit your own question!", @divTrunc((layout.screen_width - submit_width), 2), layout.question_y, types.LARGE_FONT_SIZE, state.fg_color);

    // Draw input box
    rl.drawRectangleLinesEx(layout.input_box, types.INPUT_BORDER, state.fg_color);
    const input_text = if (state.input_len > 0) @as([:0]const u8, @ptrCast(&state.input_buffer)) else "[Type your question here]";
    rl.drawText(input_text, @as(i32, @intFromFloat(layout.input_box.x)) + types.TEXT_PADDING, @as(i32, @intFromFloat(layout.input_box.y)) + types.TEXT_PADDING, types.SMALL_FONT_SIZE, state.fg_color);

    // Draw cursor if input is active
    if (state.input_active and (@mod(rl.getTime() * 2.0, 2.0) < 1.0)) {
        const cursor_x = @as(i32, @intFromFloat(layout.input_box.x)) + types.TEXT_PADDING + rl.measureText(input_text, types.SMALL_FONT_SIZE);
        rl.drawRectangle(cursor_x, @as(i32, @intFromFloat(layout.input_box.y)) + types.TEXT_PADDING, types.CURSOR_WIDTH, types.CURSOR_HEIGHT, state.fg_color);
    }
}

pub fn drawAlwaysVisibleUI(state: *types.GameState, layout: UILayout) void {
    // COLOR button in top right
    rl.drawRectangleRec(layout.randomize_btn, state.fg_color);
    const color_text = "COLOR";
    const color_font_size = types.MEDIUM_FONT_SIZE;
    const color_text_width = rl.measureText(color_text, color_font_size);
    const color_text_x = @as(i32, @intFromFloat(layout.randomize_btn.x)) + @divTrunc((types.COLOR_BUTTON_WIDTH - color_text_width), 2);
    const color_text_y = @as(i32, @intFromFloat(layout.randomize_btn.y)) + @divTrunc((types.COLOR_BUTTON_HEIGHT - color_font_size), 2);
    rl.drawText(color_text, color_text_x, color_text_y, color_font_size, state.bg_color);

    // ANSWER button in bottom right
    rl.drawRectangleRec(layout.answer_btn, state.fg_color);
    rl.drawText("ANSWER", @as(i32, @intFromFloat(layout.answer_btn.x)) + types.TEXT_PADDING, @as(i32, @intFromFloat(layout.answer_btn.y)) + types.TEXT_PADDING, types.SMALL_FONT_SIZE, state.bg_color);

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
    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(state.bg_color);

    const layout = calculateLayout(state);

    // Draw state-specific UI
    switch (state.game_state) {
        .Loading, .Authenticating => drawLoadingScreen(state, layout),
        .Answering => drawAnsweringScreen(state, layout),
        .Finished => drawFinishedScreen(state, layout),
        .Submitting => drawSubmittingScreen(state, layout),
    }

    // Always-visible UI elements
    drawAlwaysVisibleUI(state, layout);
}
