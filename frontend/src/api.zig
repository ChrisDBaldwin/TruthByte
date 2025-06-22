const std = @import("std");
const types = @import("types.zig");
const utils = @import("utils.zig");

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
    std.debug.print("🔍 Target OS: {any}\n", .{builtin.target.os.tag});

    // Initialize authentication
    if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) {
        std.debug.print("🌐 Calling JavaScript init_auth...\n", .{});
        utils.js.init_auth(on_auth_complete);
    } else {
        // For native builds, skip auth and go to loading
        std.debug.print("🖥️ Native build detected, skipping auth...\n", .{});
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
    std.debug.print("🔄 startSession called, target OS: {any}\n", .{builtin.target.os.tag});

    // Call fetch_questions API
    if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) {
        std.debug.print("🌐 Calling JavaScript fetch_questions...\n", .{});
        utils.js.fetch_questions(7, null, 0, on_questions_received);
    } else {
        // For native builds, use fallback immediately
        std.debug.print("🖥️ Native build detected, using fallback questions...\n", .{});
        initSessionWithFallback(state);
    }
}

pub fn submitResponseBatch(user_session_response: *types.UserSessionResponse) void {
    std.debug.print("🚀 submitResponseBatch called!\n", .{});

    user_session_response.session_id = utils.js.get_session_id_slice();
    user_session_response.token = utils.js.get_token_slice();
    user_session_response.trust = user_session_response.trust;
    user_session_response.invitable = false; // TODO: implement
    user_session_response.responses = user_session_response.responses;
    user_session_response.timestamp = std.time.timestamp();

    std.debug.print("📤 Submitting session:\n  session_id: {s}\n  token: {s}\n  timestamp: {d}\n  trust: {d}\n  invitable: {}\n", .{
        user_session_response.session_id,
        user_session_response.token,
        user_session_response.timestamp,
        user_session_response.trust,
        user_session_response.invitable,
    });

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

    // Serialize to JSON using a fixed buffer allocator for better memory control
    var json_buffer: [16384]u8 = undefined; // 16KB buffer
    var fba = std.heap.FixedBufferAllocator.init(&json_buffer);
    const allocator = fba.allocator();

    const json_str = std.json.stringifyAlloc(allocator, answers_for_api, .{}) catch |err| {
        std.debug.print("❌ Failed to serialize response to JSON: {any}\n", .{err});
        return;
    };

    std.debug.print("📝 JSON payload: {s}\n", .{json_str});
    std.debug.print("🌐 Calling js.submit_answers...\n", .{});

    utils.js.submit_answers(json_str.ptr, json_str.len, on_submit_complete);
}

// --- Callback Functions ---

// Callback function for authentication initialization
export fn on_auth_complete(success: i32) callconv(.C) void {
    std.debug.print("🔔 on_auth_complete called with success: {}\n", .{success});

    if (g_state == null) {
        std.debug.print("❌ g_state is null in on_auth_complete!\n", .{});
        return;
    }
    const state = g_state.?;

    if (success == 1) {
        // Authentication successful
        std.debug.print("✅ Authentication successful!\n", .{});
        state.auth_initialized = true;
        // Now load questions
        startSession(state);
    } else {
        // Authentication failed
        std.debug.print("❌ Authentication failed!\n", .{});
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
        std.debug.print("Answers submitted successfully: {}\n", .{success});
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
    std.debug.print("Raw data_len parameter: {}\n", .{data_len});
    // JavaScript adds +1 for null terminator, but JSON parser doesn't want that
    const actual_len = if (data_len > 0 and data_ptr[data_len - 1] == 0) data_len - 1 else data_len;
    const json_str = data_ptr[0..actual_len];
    std.debug.print("Adjusted JSON string length: {}\n", .{json_str.len});
    std.debug.print("Received questions JSON: {s}\n", .{json_str});

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

// JSON parsing function using struct-based deserialization
fn parseQuestionsFromJson(state: *types.GameState, json_str: []const u8) ?[7]types.Question {
    _ = state; // Parameter not used in parsing logic

    var backing_buffer: [16384]u8 = undefined; // 16KB buffer for JSON parsing, tune as needed
    var fba = std.heap.FixedBufferAllocator.init(&backing_buffer);
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
    std.debug.print("✅ JSON parsed successfully! Found {} questions\n", .{response.questions.len});
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
