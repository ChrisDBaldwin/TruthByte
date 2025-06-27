const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const types = @import("types.zig");
const utils = @import("utils.zig");

// --- Input Security Constants ---

const MAX_QUESTION_LENGTH = 200;
const MAX_TAG_LENGTH = 50;
const MAX_TAGS_TOTAL_LENGTH = 150;
const MIN_QUESTION_LENGTH = 5;

// --- Input Validation Functions ---

/// Check if a character is safe for text input (printable ASCII + basic punctuation)
fn isSafeChar(char: u8) bool {
    return switch (char) {
        // Basic printable ASCII
        32...126 => true,
        // Allow some common extended characters but be restrictive
        else => false,
    };
}

/// Check if a character is allowed in tags (more restrictive)
pub fn isSafeTagChar(char: u8) bool {
    return switch (char) {
        // Letters, numbers, spaces, hyphens, underscores
        'a'...'z', 'A'...'Z', '0'...'9', ' ', '-', '_' => true,
        else => false,
    };
}

/// Sanitize input by removing dangerous characters and limiting length
fn sanitizeInput(input: []const u8, output: []u8, max_len: usize, is_tag: bool) usize {
    var out_len: usize = 0;
    var consecutive_spaces: u32 = 0;

    for (input) |char| {
        if (out_len >= max_len - 1) break; // Leave room for null terminator

        // Choose validation function based on input type
        const is_safe = if (is_tag) isSafeTagChar(char) else isSafeChar(char);

        if (is_safe) {
            // Limit consecutive spaces
            if (char == ' ') {
                consecutive_spaces += 1;
                if (consecutive_spaces > 2) continue; // Skip excessive spaces
            } else {
                consecutive_spaces = 0;
            }

            output[out_len] = char;
            out_len += 1;
        }
        // Silently drop unsafe characters
    }

    // Trim trailing spaces
    while (out_len > 0 and output[out_len - 1] == ' ') {
        out_len -= 1;
    }

    return out_len;
}

/// Validate that input doesn't contain suspicious patterns
fn containsSuspiciousContent(input: []const u8) bool {
    // Check for binary content (non-printable characters)
    for (input) |char| {
        if (char < 32 and char != '\n' and char != '\r' and char != '\t') {
            return true; // Contains binary/control characters
        }
    }

    // Check for common injection patterns
    const suspicious_patterns = [_][]const u8{
        "<script",
        "javascript:",
        "data:",
        "vbscript:",
        "onload=",
        "onerror=",
        "onclick=",
        "eval(",
        "document.",
        "window.",
        "\\x",
        "\\u",
        "%3C", // URL encoded <
        "%3E", // URL encoded >
        "&#", // HTML entities
    };

    // Convert to lowercase for case-insensitive checking
    var lowercase_buffer: [512]u8 = undefined;
    if (input.len > lowercase_buffer.len) return true; // Suspiciously long input

    for (input, 0..) |char, i| {
        lowercase_buffer[i] = std.ascii.toLower(char);
    }
    const lowercase_input = lowercase_buffer[0..input.len];

    for (suspicious_patterns) |pattern| {
        if (std.mem.indexOf(u8, lowercase_input, pattern) != null) {
            return true;
        }
    }

    return false;
}

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
    if (state.game_state != .Submitting or (!state.input_active and !state.tags_input_active)) return;

    // Determine if we should use HTML input (mobile/touch) or raylib input (PC/mouse)
    const use_html_input = utils.js.isTextInputFocused() and state.last_touch_active;

    // Check if HTML text input is focused AND we're using touch input - if so, sync text from it
    if (use_html_input) {
        const html_input_text = utils.js.getTextInputValueSlice();

        // SECURITY: Validate and sanitize HTML input
        if (containsSuspiciousContent(html_input_text)) {
            // Clear malicious input and deactivate input field
            if (state.input_active) {
                state.input_len = 0;
                state.input_buffer[0] = 0;
                state.input_active = false;
            } else if (state.tags_input_active) {
                state.tags_input_len = 0;
                state.tags_input_buffer[0] = 0;
                state.tags_input_active = false;
            }
            _ = utils.js.clearTextInput(); // Clear the HTML input as well
            return;
        }

        if (state.input_active) {
            // Sanitize and copy to question input buffer
            const sanitized_len = sanitizeInput(html_input_text, state.input_buffer[0..], @min(MAX_QUESTION_LENGTH, state.input_buffer.len), false);
            state.input_len = sanitized_len;
            state.input_buffer[state.input_len] = 0; // Null terminate
        } else if (state.tags_input_active) {
            // Sanitize and copy to tags input buffer
            const sanitized_len = sanitizeInput(html_input_text, state.tags_input_buffer[0..], @min(MAX_TAGS_TOTAL_LENGTH, state.tags_input_buffer.len), true);
            state.tags_input_len = sanitized_len;
            state.tags_input_buffer[state.tags_input_len] = 0; // Null terminate
        }

        // Handle backspace for HTML input as well
        if (rl.isKeyPressed(.backspace)) {
            if (state.input_active and state.input_len > 0) {
                state.input_len -= 1;
                state.input_buffer[state.input_len] = 0; // Clear the removed character
                // Update the HTML input to match
                _ = utils.js.setTextInputValueFromString(state.input_buffer[0..state.input_len]);
            } else if (state.tags_input_active and state.tags_input_len > 0) {
                state.tags_input_len -= 1;
                state.tags_input_buffer[state.tags_input_len] = 0; // Clear the removed character
                // Update the HTML input to match
                _ = utils.js.setTextInputValueFromString(state.tags_input_buffer[0..state.tags_input_len]);
            }
        }

        return; // Skip raylib input handling when HTML input is active for touch users
    }

    // Use raylib input handling for PC/mouse users or when HTML input is not active
    var key = rl.getCharPressed();
    while (key > 0) : (key = rl.getCharPressed()) {
        // SECURITY: Validate character before adding
        const char = @as(u8, @intCast(key));

        if (state.input_active and state.input_len < @min(MAX_QUESTION_LENGTH, state.input_buffer.len - 1)) {
            if (isSafeChar(char)) {
                state.input_buffer[state.input_len] = char;
                state.input_len += 1;
            }
        } else if (state.tags_input_active and state.tags_input_len < @min(MAX_TAGS_TOTAL_LENGTH, state.tags_input_buffer.len - 1)) {
            if (isSafeTagChar(char)) {
                state.tags_input_buffer[state.tags_input_len] = char;
                state.tags_input_len += 1;
            }
        }
    }

    if (rl.isKeyPressed(.backspace)) {
        if (state.input_active and state.input_len > 0) {
            state.input_len -= 1;
            state.input_buffer[state.input_len] = 0; // Clear the removed character
        } else if (state.tags_input_active and state.tags_input_len > 0) {
            state.tags_input_len -= 1;
            state.tags_input_buffer[state.tags_input_len] = 0; // Clear the removed character
        }
    }

    // Null-terminate both buffers
    state.input_buffer[state.input_len] = 0;
    state.tags_input_buffer[state.tags_input_len] = 0;
}

/// Validate question input before submission
pub fn validateQuestionInput(question: []const u8, tags: []const u8) bool {
    // Check minimum length
    if (question.len < MIN_QUESTION_LENGTH) {
        // DEBUG: console.log equivalent for debugging
        return false;
    }

    // Check maximum length
    if (question.len > MAX_QUESTION_LENGTH) return false;

    // Check for suspicious content
    if (containsSuspiciousContent(question)) return false;
    if (containsSuspiciousContent(tags)) return false;

    // Ensure question has some content after trimming
    const trimmed_question = std.mem.trim(u8, question, " \t\n\r");
    if (trimmed_question.len == 0) return false;

    // Check for repeated characters (spam detection)
    if (hasExcessiveRepeatedChars(trimmed_question)) return false;

    // Ensure question has some meaningful content (not just punctuation/spaces)
    var letter_count: u32 = 0;
    for (trimmed_question) |char| {
        if ((char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z')) {
            letter_count += 1;
        }
    }
    if (letter_count < 3) return false; // Need at least 3 letters (more reasonable)

    // Tags validation
    if (tags.len == 0) return false; // Must have at least one tag
    if (tags.len > MAX_TAGS_TOTAL_LENGTH) return false;

    return true;
}

/// Check for excessive repeated characters (spam detection)
fn hasExcessiveRepeatedChars(text: []const u8) bool {
    if (text.len < 4) return false;

    var consecutive_count: u32 = 1;
    var prev_char: u8 = text[0];

    for (text[1..]) |char| {
        if (char == prev_char) {
            consecutive_count += 1;
            if (consecutive_count > 4) return true; // More than 4 consecutive same chars
        } else {
            consecutive_count = 1;
            prev_char = char;
        }
    }

    return false;
}
