const std = @import("std");
const types = @import("types.zig");
const utils = @import("utils.zig");
const user = @import("user.zig");

// Global state pointer for callbacks (needed because callbacks can't capture context)
pub var g_state: ?*types.GameState = null;

// --- Session Management Functions ---

pub fn startAuthentication(state: *types.GameState) void {
    state.game_state = .Authenticating;
    state.loading_message = "Connecting to server...";
    state.loading_start_time = std.time.timestamp();

    // Set global state for callback
    g_state = state;

    const builtin = @import("builtin");

    // Initialize authentication
    if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) {
        utils.js.init_auth(on_auth_complete);
    } else {
        // For native builds, skip auth and go to loading
        state.auth_initialized = true;
        startSession(state);
    }
}

pub fn startSession(state: *types.GameState) void {
    state.game_state = .Loading;
    state.loading_message = "Loading questions...";
    state.loading_start_time = std.time.timestamp();

    // Set global state for callback
    g_state = state;

    const builtin = @import("builtin");

    // Call fetch_questions API
    if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) {
        const user_id_slice = user.getUserIDSlice();
        utils.js.fetch_questions(7, null, 0, user_id_slice.ptr, user_id_slice.len, on_questions_received);
    } else {
        // For native builds, use fallback immediately
        initSessionWithFallback(state);
    }
}

pub fn submitResponseBatch(user_session_response: *types.UserSessionResponse) void {
    user_session_response.session_id = utils.js.get_session_id_slice();
    user_session_response.token = utils.js.get_token_slice();
    user_session_response.trust = user_session_response.trust;
    user_session_response.invitable = false; // TODO: implement
    user_session_response.responses = user_session_response.responses;
    user_session_response.timestamp = std.time.timestamp();

    // Convert responses to the format expected by the lambda (list of answers with user_id)
    // The lambda expects: [{"user_id": str, "question_id": str, "answer": bool, "timestamp": number}]
    var answers_for_api: [7]struct {
        user_id: []const u8,
        question_id: []const u8,
        answer: ?bool,
        timestamp: i64,
    } = undefined;

    var i: usize = 0;
    while (i < 7) : (i += 1) {
        answers_for_api[i] = .{
            .user_id = user_session_response.session_id,
            .question_id = user_session_response.responses[i].question_id,
            .answer = user_session_response.responses[i].answer,
            .timestamp = user_session_response.responses[i].start_time,
        };
    }

    // Serialize to JSON using the global buffer to avoid stack issues
    var fba = std.heap.FixedBufferAllocator.init(&global_json_buffer);
    const allocator = fba.allocator();

    const json_str = std.json.stringifyAlloc(allocator, answers_for_api, .{}) catch |err| {
        std.debug.print("❌ Failed to serialize response to JSON: {any}\n", .{err});
        return;
    };

    const user_id_slice = user.getUserIDSlice();
    utils.js.submit_answers(json_str.ptr, json_str.len, user_id_slice.ptr, user_id_slice.len, on_submit_complete);
}

// --- Callback Functions ---

// Callback function for authentication initialization
export fn on_auth_complete(success: i32) callconv(.C) void {
    if (g_state == null) {
        std.debug.print("❌ g_state is null in on_auth_complete!\n", .{});
        return;
    }
    const state = g_state.?;

    if (success == 1) {
        // Authentication successful
        state.auth_initialized = true;
        // Now load questions
        startSession(state);
    } else {
        // Authentication failed
        state.loading_message = "Authentication failed. Using offline mode.";
        state.auth_initialized = false;
        // Use fallback questions without authentication
        initSessionWithFallback(state);
    }
}

// Callback function for submit_answers API response
export fn on_submit_complete(success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void {
    if (g_state == null) return;
    if (success == 1) {
        // Answers submitted successfully
    } else {
        const error_msg = if (data_len > 0) data_ptr[0..data_len] else "Unknown error";
        std.debug.print("Failed to submit answers: {s}\n", .{error_msg});
    }
}

// Callback function for fetch_questions API response
export fn on_questions_received(success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void {
    if (g_state == null) {
        std.debug.print("❌ g_state is null in on_questions_received!\n", .{});
        return;
    }
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
    // JavaScript adds +1 for null terminator, but JSON parser doesn't want that
    const actual_len = if (data_len > 0 and data_ptr[data_len - 1] == 0) data_len - 1 else data_len;
    const json_str = data_ptr[0..actual_len];

    // Parse JSON and create questions from API response
    if (parseQuestionsFromJson(state, json_str)) |parsed_questions| {
        state.loading_message = "Questions loaded!";
        initSessionWithParsedQuestions(state, parsed_questions);
    } else {
        // JSON parsing failed, use fallback
        state.loading_message = "Failed to parse questions. Using fallback.";
        initSessionWithFallback(state);
    }
}

// --- JSON Parsing Functions ---

// Global buffer for JSON parsing to avoid stack overflow
var global_json_buffer: [8192]u8 = undefined; // Reduced from 16KB to 8KB and moved to global

// JSON parsing function using struct-based deserialization
fn parseQuestionsFromJson(state: *types.GameState, json_str: []const u8) ?[7]types.Question {
    _ = state; // Parameter not used in parsing logic

    // Use global buffer to avoid stack overflow in WASM
    var fba = std.heap.FixedBufferAllocator.init(&global_json_buffer);
    const allocator = fba.allocator();

    // Parse JSON into struct
    const parsed = std.json.parseFromSlice(types.APIResponseJSON, allocator, json_str, .{}) catch |err| {
        std.debug.print("Failed to parse JSON: {any}\n", .{err});
        std.debug.print("JSON length: {}\n", .{json_str.len});
        std.debug.print("JSON preview: {s}\n", .{json_str[0..@min(json_str.len, 300)]});
        return null;
    };
    defer parsed.deinit();

    const response = parsed.value;
    var questions: [7]types.Question = undefined;
    var question_count: usize = 0;

    // Convert JSON questions to internal Question structs
    for (response.questions) |question_json| {
        if (question_count >= 7) break;

        // Convert using allocator method
        questions[question_count] = question_json.toQuestion(allocator) catch {
            std.debug.print("Failed to convert question {s}\n", .{question_json.id});
            continue;
        };

        question_count += 1;
    }

    // Fill remaining slots with fallback questions if needed
    while (question_count < 7) {
        const fallback_idx = question_count % types.question_pool.len;
        questions[question_count] = types.question_pool[fallback_idx];
        question_count += 1;
    }

    if (question_count > 0) {
        return questions;
    } else {
        return null;
    }
}

// --- Session Initialization Functions ---

// Initialize session with parsed questions from API
fn initSessionWithParsedQuestions(state: *types.GameState, questions: [7]types.Question) void {
    state.session = types.Session{
        .questions = questions,
        .current = 0,
        .correct = 0,
        .finished = false,
    };

    // Initialize response tracking
    for (0..7) |i| {
        state.user_session.responses[i] = types.QuestionResponse{
            .question_id = state.session.questions[i].id,
            .answer = null,
            .start_time = 0,
            .duration = 0,
        };
    }
    state.game_state = .Answering;
}

pub fn initSessionWithFallback(state: *types.GameState) void {
    state.session = types.Session{
        .questions = types.question_pool[0..7].*,
        .current = 0,
        .correct = 0,
        .finished = false,
    };

    // Initialize response tracking
    for (0..7) |i| {
        state.user_session.responses[i] = types.QuestionResponse{
            .question_id = state.session.questions[i].id,
            .answer = null,
            .start_time = 0,
            .duration = 0,
        };
    }
    state.game_state = .Answering;
}
