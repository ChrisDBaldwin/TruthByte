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

pub fn startUserDataFetch(state: *types.GameState) void {
    state.loading_message = "Loading user data...";

    // Set global state for callback
    g_state = state;

    const builtin = @import("builtin");

    // Fetch user data to get streak information
    if (builtin.target.os.tag == .emscripten or builtin.target.os.tag == .freestanding) {
        const user_id_slice = user.getUserIDSlice();
        utils.js.fetch_user(user_id_slice.ptr, user_id_slice.len, on_user_data_received);
    } else {
        // For native builds, skip user data fetch and go to mode selection
        startModeSelection(state);
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
        utils.js.fetch_questions(7, null, 0, 0, user_id_slice.ptr, user_id_slice.len, on_questions_received);
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
        utils.js.fetch_questions(7, category_ptr, category.len, diff_param, user_id_slice.ptr, user_id_slice.len, on_questions_received);
    } else {
        // For native builds, use fallback immediately
        initSessionWithFallback(state);
    }
}

pub fn submitResponseBatch(user_session_response: *types.UserSessionResponse) void {
    user_session_response.session_id = utils.js.get_session_id_slice();
    user_session_response.token = utils.js.get_token_slice();
    user_session_response.trust = user_session_response.trust;
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
        // Authentication successful - now fetch user data
        state.auth_initialized = true;
        startUserDataFetch(state);
    } else {
        // Authentication failed - initialize offline state
        std.debug.print("Authentication failed, initializing offline state\n", .{});
        state.loading_message = "Authentication failed. Using offline mode.";
        state.auth_initialized = false;
        state.daily_completed_today = false; // Ensure daily mode is available in offline mode
        state.current_streak = 0;
        state.best_streak = 0;
        startModeSelection(state);
    }
}

// Callback function for user data fetch
export fn on_user_data_received(success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void {
    if (g_state == null) {
        std.debug.print("❌ g_state is null in on_user_data_received!\n", .{});
        return;
    }
    const state = g_state.?;

    if (success == 1) {
        // Parse JSON response to extract user data
        const actual_len = if (data_len > 0 and data_ptr[data_len - 1] == 0) data_len - 1 else data_len;
        const json_str = data_ptr[0..actual_len];

        // Use global buffer to avoid stack overflow in WASM
        var fba = std.heap.FixedBufferAllocator.init(&global_json_buffer);
        const allocator = fba.allocator();

        // Parse JSON response safely
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_str, .{}) catch |err| {
            std.debug.print("Failed to parse user data JSON: {any}\n", .{err});
            // Even if parsing fails, go to mode selection
            startModeSelection(state);
            return;
        };
        defer parsed.deinit();

        const response = parsed.value;

        // Extract streak information (integers in the response)
        if (response.object.get("current_daily_streak")) |current_value| {
            if (current_value == .integer) {
                state.current_streak = @as(u32, @intCast(current_value.integer));
            }
        }

        if (response.object.get("best_daily_streak")) |best_value| {
            if (best_value == .integer) {
                state.best_streak = @as(u32, @intCast(best_value.integer));
            }
        }

        // Extract daily progress if available
        if (response.object.get("daily_progress")) |progress_value| {
            // Get current date from JavaScript
            const date_str = utils.js.get_current_date_slice();

            // Debug logging
            std.debug.print("Daily progress found. Is object: {}, Is empty: {}\n", .{
                progress_value == .object,
                if (progress_value == .object) progress_value.object.count() == 0 else false,
            });

            // Handle empty object case
            if (progress_value == .object and progress_value.object.count() == 0) {
                std.debug.print("Empty daily progress object, skipping\n", .{});
                state.daily_completed_today = false;
            } else if (progress_value.object.get(date_str)) |today_progress| {
                std.debug.print("Found progress for today\n", .{});
                if (today_progress.object.get("answers")) |answers_value| {
                    if (answers_value == .array and answers_value.array.items.len > 0) {
                        std.debug.print("Found {} answers for today\n", .{answers_value.array.items.len});
                        state.daily_completed_today = true;

                        // Calculate stats
                        var correct: u32 = 0;
                        const total: u32 = answers_value.array.items.len;

                        // Count correct answers
                        for (answers_value.array.items) |answer| {
                            if (answer.object.get("is_correct")) |is_correct| {
                                if (is_correct == .bool and is_correct.bool) {
                                    correct += 1;
                                }
                            }
                        }

                        state.daily_correct_count = correct;
                        state.daily_total_questions = total;

                        // Calculate score and rank based on counts
                        if (total > 0) {
                            state.daily_score = (@as(f32, @floatFromInt(correct)) / @as(f32, @floatFromInt(total))) * 100.0;
                        } else {
                            state.daily_score = 0.0;
                        }

                        const rank_char: u8 = if (state.daily_score >= 90.0)
                            'A'
                        else if (state.daily_score >= 80.0)
                            'B'
                        else if (state.daily_score >= 70.0)
                            'C'
                        else if (state.daily_score >= 60.0)
                            'D'
                        else
                            'F';
                        state.daily_rank[0] = rank_char;
                        state.daily_rank[1] = 0;
                    }
                }
            }
        }

        std.debug.print("Successfully loaded user data - current_streak: {}, best_streak: {}, daily_score: {}%\n", .{ state.current_streak, state.best_streak, state.daily_score });
    } else {
        // Handle error - just continue without user data
        const error_msg = if (data_len > 0) data_ptr[0..data_len] else "Unknown error";
        std.debug.print("Failed to fetch user data: {s}\n", .{error_msg});
        // Initialize streak and daily mode state to 0/false if fetch failed
        state.current_streak = 0;
        state.best_streak = 0;
        state.daily_completed_today = false;
        state.daily_correct_count = 0;
        state.daily_total_questions = 0;
        state.daily_score = 0.0;
        state.daily_rank[0] = 'F';
        state.daily_rank[1] = 0;
    }

    // After processing user data (or error), go to mode selection
    startModeSelection(state);
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
var global_json_buffer: [16384]u8 = undefined; // Increased to 16KB for daily questions with metadata

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
    var session_questions: [10]types.Question = undefined;
    @memcpy(session_questions[0..7], questions[0..7]);

    state.session = types.Session{
        .questions = session_questions,
        .current = 0,
        .correct = 0,
        .finished = false,
        .total_questions = 7,
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
    var session_questions: [10]types.Question = undefined;
    @memcpy(session_questions[0..7], types.question_pool[0..7]);

    state.session = types.Session{
        .questions = session_questions,
        .current = 0,
        .correct = 0,
        .finished = false,
        .total_questions = 7,
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

// --- Daily Mode Functions ---

pub fn startModeSelection(state: *types.GameState) void {
    state.game_state = .ModeSelection;
}

pub fn startDailyMode(state: *types.GameState) void {
    // Initialize session for Daily mode before making API call
    state.selected_mode = .Daily;
    state.session.total_questions = 10;
    state.session.current = 0;
    state.session.correct = 0;
    state.session.finished = false;
    // If daily challenge is already completed today, go directly to review screen
    if (state.daily_completed_today) {
        state.game_state = .DailyReview;
        return;
    }

    state.loading_message = "Loading daily challenge...";
    state.game_state = .Loading;
    state.loading_start_time = std.time.timestamp();

    // Fetch daily questions
    const user_id_slice = user.getUserIDSlice();
    utils.js.fetch_daily_questions(user_id_slice.ptr, user_id_slice.len, on_daily_questions_received);
}

// Callback for daily questions API response
export fn on_daily_questions_received(success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void {
    if (g_state == null) {
        std.debug.print("❌ g_state is null in on_daily_questions_received!\n", .{});
        return;
    }
    const state = g_state.?;

    if (success == 0) {
        // Error occurred
        const error_msg = data_ptr[0..data_len];
        std.debug.print("Failed to fetch daily questions: {s}\n", .{error_msg});
        state.loading_message = "Failed to load daily challenge.";
        // Go back to mode selection
        state.game_state = .ModeSelection;
        return;
    }

    // Parse JSON response
    const actual_len = if (data_len > 0 and data_ptr[data_len - 1] == 0) data_len - 1 else data_len;
    const json_str = data_ptr[0..actual_len];

    // Parse daily questions JSON
    if (parseDailyQuestionsFromJson(state, json_str)) {
        state.loading_message = "Daily challenge loaded!";
        state.game_state = .Answering;
    } else {
        state.loading_message = "Failed to parse daily challenge.";
        state.game_state = .ModeSelection;
    }
}

fn parseDailyQuestionsFromJson(state: *types.GameState, json_str: []const u8) bool {
    // Use global buffer to avoid stack overflow in WASM
    var fba = std.heap.FixedBufferAllocator.init(&global_json_buffer);
    const allocator = fba.allocator();

    // Parse JSON into generic value first
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_str, .{}) catch |err| {
        std.debug.print("Failed to parse daily JSON: {any}\n", .{err});
        return false;
    };
    defer parsed.deinit();

    const response = parsed.value;

    // Extract questions array
    const questions_value = response.object.get("questions") orelse return false;
    const questions_array = questions_value.array;

    // Extract daily progress
    if (response.object.get("daily_progress")) |progress_value| {
        // Get current date from JavaScript
        const date_str = utils.js.get_current_date_slice();

        // Debug logging
        std.debug.print("Daily progress found in questions response. Is object: {}, Is empty: {}\n", .{
            progress_value == .object,
            if (progress_value == .object) progress_value.object.count() == 0 else false,
        });

        // Skip if it's an empty object
        if (progress_value == .object and progress_value.object.count() == 0) {
            std.debug.print("Empty daily progress object in questions response, skipping\n", .{});
            state.daily_completed_today = false;
            return true;
        }

        // Check for answers for today
        if (progress_value.object.get(date_str)) |today_progress| {
            std.debug.print("Found progress for today in questions response\n", .{});
            if (today_progress.object.get("answers")) |answers_value| {
                if (answers_value == .array and answers_value.array.items.len > 0) {
                    state.daily_completed_today = true;

                    // Calculate stats
                    var correct: u32 = 0;
                    const total: u32 = answers_value.array.items.len;

                    // Count correct answers
                    for (answers_value.array.items) |answer| {
                        if (answer.object.get("is_correct")) |is_correct| {
                            if (is_correct == .bool and is_correct.bool) {
                                correct += 1;
                            }
                        }
                    }

                    state.daily_correct_count = correct;
                    state.daily_total_questions = total;

                    // Calculate score and rank based on counts
                    if (total > 0) {
                        state.daily_score = (@as(f32, @floatFromInt(correct)) / @as(f32, @floatFromInt(total))) * 100.0;
                    } else {
                        state.daily_score = 0.0;
                    }

                    const rank_char: u8 = if (state.daily_score >= 90.0)
                        'A'
                    else if (state.daily_score >= 80.0)
                        'B'
                    else if (state.daily_score >= 70.0)
                        'C'
                    else if (state.daily_score >= 60.0)
                        'D'
                    else
                        'F';
                    state.daily_rank[0] = rank_char;
                    state.daily_rank[1] = 0;
                }
            }
        }
    }

    // Extract streak info
    if (response.object.get("streak_info")) |streak_value| {
        if (streak_value.object.get("current_streak")) |current_value| {
            const raw_value = current_value.float;
            if (raw_value >= 0 and raw_value <= 10000) { // Reasonable bounds
                const converted_value = @as(u32, @intFromFloat(raw_value));
                state.current_streak = converted_value;
            } else {
                state.current_streak = 0;
            }
        }
        if (streak_value.object.get("best_streak")) |best_value| {
            const raw_value = best_value.float;
            if (raw_value >= 0 and raw_value <= 10000) { // Reasonable bounds
                const converted_value = @as(u32, @intFromFloat(raw_value));
                state.best_streak = converted_value;
            } else {
                state.best_streak = 0;
            }
        }
    }

    // Convert questions (up to 10 for daily mode)
    var questions: [10]types.Question = undefined;
    var question_count: usize = 0;

    for (questions_array.items) |question_value| {
        if (question_count >= 10) break;

        const question_obj = question_value.object;

        // Extract question data
        const id = question_obj.get("id").?.string;
        const question_text = question_obj.get("question").?.string;
        const answer = question_obj.get("answer").?.bool;

        // Copy to persistent storage in GameState
        const id_len = @min(id.len, 31);
        @memcpy(state.daily_question_ids[question_count][0..id_len], id[0..id_len]);
        state.daily_question_ids[question_count][id_len] = 0;

        const q_len = @min(question_text.len, 511);
        @memcpy(state.daily_question_texts[question_count][0..q_len], question_text[0..q_len]);
        state.daily_question_texts[question_count][q_len] = 0;

        questions[question_count] = types.Question{
            .id = state.daily_question_ids[question_count][0..id_len :0],
            .question = state.daily_question_texts[question_count][0..q_len :0],
            .answer = answer,
        };

        question_count += 1;
    }

    if (question_count == 0) return false;

    // Initialize daily session
    state.session = types.Session{
        .questions = questions,
        .current = 0,
        .correct = 0,
        .finished = false,
        .mode = .Daily,
        .total_questions = question_count,
    };

    // Initialize response tracking
    const responses_len = @min(question_count, state.user_session.responses.len);
    for (0..responses_len) |i| {
        state.user_session.responses[i] = types.QuestionResponse{
            .question_id = state.session.questions[i].id,
            .answer = null,
            .start_time = 0,
            .duration = 0,
        };
    }

    return true;
}

pub fn submitDailyAnswers(state: *types.GameState) void {
    // Use global buffer to avoid stack overflow in WASM
    var fba = std.heap.FixedBufferAllocator.init(&global_json_buffer);
    const allocator = fba.allocator();

    // Create minimal answers array - just question IDs and answers
    var answers = std.ArrayList(struct {
        question_id: []const u8,
        answer: bool,
    }).init(allocator);
    defer answers.deinit();

    for (0..state.session.total_questions) |i| {
        const response = state.user_session.responses[i];
        if (response.answer != null) {
            answers.append(.{
                .question_id = response.question_id,
                .answer = response.answer.?,
            }) catch |err| {
                std.debug.print("Failed to append answer {}: {any}\n", .{ i, err });
                continue;
            };
        }
    }

    // Create minimal submission object - just the answers
    const submission = .{
        .answers = answers.items,
    };

    const json_str = std.json.stringifyAlloc(allocator, submission, .{}) catch |err| {
        std.debug.print("Failed to stringify daily submission: {any}\n", .{err});
        // If JSON creation fails, go to finished state
        state.game_state = .Finished;
        return;
    };

    // Submit to backend
    const user_id_slice = user.getUserIDSlice();
    utils.js.submit_daily_answers(json_str.ptr, json_str.len, user_id_slice.ptr, user_id_slice.len, on_daily_answers_submitted);
}

// Callback for daily answers submission
export fn on_daily_answers_submitted(success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void {
    if (g_state == null) return;
    const state = g_state.?;

    if (success == 1) {
        // Successfully submitted - we have the results from the session.
        // Update the state for the review screen.
        state.daily_completed_today = true;
        state.daily_correct_count = @as(u32, @intCast(state.session.correct));
        state.daily_total_questions = @as(u32, @intCast(state.session.total_questions));

        if (state.daily_total_questions > 0) {
            state.daily_score = (@as(f32, @floatFromInt(state.daily_correct_count)) / @as(f32, @floatFromInt(state.daily_total_questions))) * 100.0;
        } else {
            state.daily_score = 0.0;
        }

        // Calculate rank
        const rank_char: u8 = if (state.daily_score >= 90.0)
            'A'
        else if (state.daily_score >= 80.0)
            'B'
        else if (state.daily_score >= 70.0)
            'C'
        else if (state.daily_score >= 60.0)
            'D'
        else
            'F';
        state.daily_rank[0] = rank_char;
        state.daily_rank[1] = 0;

        // Now go to review screen
        state.game_state = .DailyReview;
    } else {
        // Handle error - go to finished state instead of crashing
        const error_msg = if (data_len > 0) data_ptr[0..data_len] else "Unknown error";
        std.debug.print("Failed to submit daily answers: {s}\n", .{error_msg});
        state.game_state = .Finished;
    }
}

pub fn startArcadeMode(state: *types.GameState) void {
    state.selected_mode = .Arcade;
    startSession(state);
}

pub fn startCategoriesMode(state: *types.GameState) void {
    state.selected_mode = .Categories;
    startCategorySelection(state);
}
