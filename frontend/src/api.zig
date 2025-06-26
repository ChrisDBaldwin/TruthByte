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

pub fn startCategorySelection(state: *types.GameState) void {
    state.game_state = .Loading;
    state.loading_message = "Loading categories...";
    state.loading_start_time = std.time.timestamp();
    state.categories_loading = true;

    // Set global state for callback
    g_state = state;

    const builtin = @import("builtin");

    // Call fetch_categories API
    if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) {
        const user_id_slice = user.getUserIDSlice();
        utils.js.fetch_categories(user_id_slice.ptr, user_id_slice.len, on_categories_received);
    } else {
        // For native builds, show fallback categories
        initCategoriesWithFallback(state);
    }
}

pub fn startSessionWithCategory(state: *types.GameState, category: []const u8, difficulty: ?u8) void {
    state.game_state = .Loading;
    state.loading_message = "Loading questions...";
    state.loading_start_time = std.time.timestamp();

    // Store selected filters in session
    state.session.selected_category = category;
    state.session.selected_difficulty = difficulty;

    // Set global state for callback
    g_state = state;

    const builtin = @import("builtin");

    // Call enhanced fetch_questions API with category and difficulty
    if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) {
        const user_id_slice = user.getUserIDSlice();
        const category_ptr = if (category.len > 0) category.ptr else null;
        const diff_param = difficulty orelse 0;
        utils.js.fetch_questions_enhanced(7, category_ptr, category.len, diff_param, user_id_slice.ptr, user_id_slice.len, on_questions_received);
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

// Callback function for fetch_categories API response
export fn on_categories_received(success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void {
    if (g_state == null) {
        std.debug.print("❌ g_state is null in on_categories_received!\n", .{});
        return;
    }
    const state = g_state.?;

    if (success == 0) {
        // Error occurred
        const error_msg = data_ptr[0..data_len];
        std.debug.print("Failed to fetch categories: {s}\n", .{error_msg});
        state.loading_message = "Failed to load categories. Using fallback.";
        // Use fallback categories
        initCategoriesWithFallback(state);
        return;
    }

    // Parse JSON response
    const actual_len = if (data_len > 0 and data_ptr[data_len - 1] == 0) data_len - 1 else data_len;
    const json_str = data_ptr[0..actual_len];

    // Parse JSON and populate categories
    if (parseCategoriesFromJson(state, json_str)) {
        state.loading_message = "Categories loaded!";
        state.categories_loading = false;
        state.game_state = .CategorySelection;
    } else {
        // JSON parsing failed, use fallback
        state.loading_message = "Failed to parse categories. Using fallback.";
        initCategoriesWithFallback(state);
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

    // Parse JSON into struct with ignore_unknown_fields to handle extra fields from database
    const parsed = std.json.parseFromSlice(types.APIResponseJSON, allocator, json_str, .{
        .ignore_unknown_fields = true,
    }) catch |err| {
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

// Helper function to parse categories from JSON
fn parseCategoriesFromJson(state: *types.GameState, json_str: []const u8) bool {
    // Use global buffer to avoid stack overflow in WASM
    var fba = std.heap.FixedBufferAllocator.init(&global_json_buffer);
    const allocator = fba.allocator();

    // Parse JSON into struct with ignore_unknown_fields to handle extra fields from database
    const parsed = std.json.parseFromSlice(types.CategoriesResponseJSON, allocator, json_str, .{
        .ignore_unknown_fields = true,
    }) catch |err| {
        std.debug.print("Failed to parse categories JSON: {any}\n", .{err});
        return false;
    };
    defer parsed.deinit();

    const response = parsed.value;
    var count: usize = 0;

    // Convert JSON categories to internal Category structs
    for (response.categories) |category_json| {
        if (count >= state.available_categories.len) break;

        // Copy category name to persistent storage in GameState
        const name_len = @min(category_json.name.len, 63); // Leave room for null terminator
        @memcpy(state.category_name_storage[count][0..name_len], category_json.name[0..name_len]);
        state.category_name_storage[count][name_len] = 0;

        state.available_categories[count] = types.Category{
            .name = state.category_name_storage[count][0..name_len], // Now points to persistent storage
            .count = category_json.count,
            .selected = false,
        };
        count += 1;
    }

    state.categories_count = count;
    return count > 0;
}

// Initialize categories with fallback data
fn initCategoriesWithFallback(state: *types.GameState) void {
    // Provide some fallback categories
    const fallback_names = [_][]const u8{
        "general",
        "science",
        "math",
        "animals",
        "food",
    };
    const fallback_counts = [_]u32{ 100, 50, 30, 25, 20 };

    const count = @min(fallback_names.len, state.available_categories.len);
    for (0..count) |i| {
        // Copy fallback names to persistent storage
        const name_len = @min(fallback_names[i].len, 63);
        @memcpy(state.category_name_storage[i][0..name_len], fallback_names[i][0..name_len]);
        state.category_name_storage[i][name_len] = 0;

        state.available_categories[i] = types.Category{
            .name = state.category_name_storage[i][0..name_len],
            .count = fallback_counts[i],
            .selected = false,
        };
    }

    state.categories_count = count;
    state.categories_loading = false;
    state.game_state = .CategorySelection;
}
