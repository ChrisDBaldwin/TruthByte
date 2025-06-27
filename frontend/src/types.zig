const std = @import("std");
const rl = @import("raylib");

// --- Layout Constants (deprecated - now using responsive system) ---
// These constants are kept for compatibility with existing UI element sizing
pub const MARGIN = 24;
pub const LARGE_FONT_SIZE = 32;
pub const MEDIUM_FONT_SIZE = 24;
pub const SMALL_FONT_SIZE = 20;
pub const ELEMENT_SPACING = 40;
pub const SMALL_SPACING = 20;
pub const MEDIUM_SPACING = 60;
pub const TEXT_PADDING = 10;
pub const BUTTON_TEXT_OFFSET_X = 60;
pub const BUTTON_TEXT_OFFSET_Y = 25;
pub const CONFIRM_TEXT_OFFSET_X = 40;
pub const CONFIRM_TEXT_OFFSET_Y = 18;
pub const THICK_BORDER = 8;
pub const THIN_BORDER = 4;
pub const INPUT_BORDER = 2;
pub const CURSOR_WIDTH = 10;
pub const CURSOR_HEIGHT = 20;

// --- UI Element Dimensions ---
pub const COLOR_BUTTON_WIDTH = 80;
pub const COLOR_BUTTON_HEIGHT = 40;
pub const BOTTOM_BUTTON_WIDTH = 110;
pub const BOTTOM_BUTTON_HEIGHT = 45;
pub const BOTTOM_BUTTON_GAP = 20;
pub const INPUT_BOX_WIDTH = 400;
pub const INPUT_BOX_HEIGHT = 40;
pub const BUTTON_GAP = 40;

// --- Category Selection UI ---
pub const CATEGORY_BUTTON_WIDTH_SMALL: i32 = 160;
pub const CATEGORY_BUTTON_WIDTH_LARGE: i32 = 200;
pub const CATEGORY_BUTTON_HEIGHT_SMALL: i32 = 55;
pub const CATEGORY_BUTTON_HEIGHT_LARGE: i32 = 80;
pub const CATEGORY_SPACING_SMALL: i32 = 8;
pub const CATEGORY_SPACING_LARGE: i32 = 12;
pub const DIFFICULTY_BUTTON_WIDTH: i32 = 60;
pub const DIFFICULTY_BUTTON_HEIGHT: i32 = 30;
pub const DIFFICULTY_BUTTON_SPACING: i32 = 10;
pub const DIFFICULTY_SECTION_HEIGHT_SMALL: i32 = 80;
pub const DIFFICULTY_SECTION_HEIGHT_LARGE: i32 = 110;
pub const DIFFICULTY_Y_OFFSET_SMALL: i32 = 50;
pub const DIFFICULTY_Y_OFFSET_LARGE: i32 = 80;
pub const BACK_BUTTON_WIDTH: i32 = 90;
pub const BACK_BUTTON_HEIGHT: i32 = 40;
pub const TITLE_SPACING: i32 = 20;
pub const MAX_CATEGORIES_PER_ROW_SMALL: i32 = 2;
pub const MAX_CATEGORIES_PER_ROW_LARGE: i32 = 4;
pub const SUBMIT_ANSWER_BUTTON_GAP: i32 = 20;
pub const SIDE_BUTTON_GAP: i32 = 8;

// --- Game Constants ---
pub const accent = rl.Color{ .r = 255, .g = 99, .b = 71, .a = 255 }; // tomato (stark)
pub const button_w = 240;
pub const button_h = 80;
pub const button_y = 220;
pub const button_gap = 60;
pub const confirm_w = 200;
pub const confirm_h = 60;
pub const confirm_y = button_y + button_h + button_gap + 30;
pub const NUM_PALETTES = 100;

// --- Type Definitions ---

pub const Palette = struct {
    bg: rl.Color,
    fg: rl.Color,
};

pub const QuestionResponse = struct {
    question_id: []const u8,
    answer: ?bool = null,
    start_time: i64 = 0,
    duration: f64 = 0.0,
};

pub const AnswerInput = struct {
    user_id: []const u8,
    question_id: []const u8,
    answer: bool,
    timestamp: i64,
};

pub const UserSessionResponse = struct {
    session_id: []const u8 = "",
    token: []const u8 = "",
    trust: f32 = 0.0,
    responses: [10]QuestionResponse,
    timestamp: i64,
};

pub const GameStateEnum = enum {
    Authenticating,
    Loading,
    ModeSelection, // New state for mode selection
    CategorySelection, // New state for category browsing
    Answering, // state for Arcade mode
    Submitting,
    SubmitThanks,
    Finished,
    DailyReview, // New state for daily mode review
};

pub const GameMode = enum {
    Arcade,
    Categories,
    Daily,
};

pub const Orientation = enum { Vertical, Horizontal };

// Category information for selection UI
pub const Category = struct {
    name: []const u8,
    count: u32,
    selected: bool = false,
};

pub const Question = struct {
    id: [:0]const u8, // Unique identifier
    categories: []const []const u8 = &.{}, // Categories (formerly tags)
    difficulty: u8 = 3, // Difficulty rating 1-5 (default: 3 - medium)
    question: [:0]const u8, // The main question text
    title: [:0]const u8 = "", // Short label/headline (optional)
    passage: [:0]const u8 = "", // Supporting passage (optional)
    answer: bool, // True/False answer
};

pub const Session = struct {
    questions: [10]Question, // Increased to support daily mode (10 questions)
    current: usize = 0,
    correct: usize = 0,
    finished: bool = false,
    selected_category: []const u8 = "general", // Track selected category
    selected_difficulty: ?u8 = null, // Track selected difficulty filter
    mode: GameMode = .Arcade, // Track which mode is being played
    total_questions: usize = 7, // Actual number of questions (7 for arcade, 10 for daily)
};

pub const GameState = struct {
    // Palette and color state
    palettes: [NUM_PALETTES]Palette = undefined,
    bg_color: rl.Color = rl.Color{ .r = 200, .g = 215, .b = 235, .a = 255 },
    fg_color: rl.Color = rl.Color{ .r = 255, .g = 245, .b = 230, .a = 255 },
    // Game/session state
    game_state: GameStateEnum = .Authenticating,
    previous_state: GameStateEnum = .Authenticating, // Track previous state for back navigation
    orientation: Orientation = .Vertical,
    auth_initialized: bool = false,
    session: Session = Session{
        .questions = std.mem.zeroes([10]Question),
        .current = 0,
        .correct = 0,
        .finished = false,
        .selected_category = "general",
        .selected_difficulty = null,
        .mode = .Arcade,
        .total_questions = 7,
    },
    user_session: UserSessionResponse = UserSessionResponse{
        .responses = std.mem.zeroes([10]QuestionResponse),
        .timestamp = 0,
    },
    user_trust: f32 = 0.0,
    sessions_completed: u32 = 0,
    loading_start_time: i64 = 0,
    // Daily mode state
    current_streak: u32 = 0,
    best_streak: u32 = 0,
    daily_completed_today: bool = false,
    daily_score: f32 = 0.0,
    daily_rank: [2]u8 = [_]u8{ 'D', 0 }, // Null-terminated rank string
    daily_correct_count: u32 = 0, // Actual correct answers from backend
    daily_total_questions: u32 = 10, // Total questions in daily challenge
    // Mode selection state
    selected_mode: GameMode = .Arcade,
    // Category selection state
    available_categories: [20]Category = undefined, // Max 20 categories
    categories_count: usize = 0,
    categories_loading: bool = false,
    // Persistent storage for category names (20 categories x 64 chars each)
    category_name_storage: [20][64]u8 = std.mem.zeroes([20][64]u8),
    selected_category_name: [64]u8 = std.mem.zeroes([64]u8), // Selected category name buffer
    selected_category_len: usize = 0,
    selected_difficulty: ?u8 = null, // 1-5 difficulty filter
    // Persistent storage for daily questions (10 questions)
    daily_question_ids: [10][32]u8 = std.mem.zeroes([10][32]u8),
    daily_question_texts: [10][512]u8 = std.mem.zeroes([10][512]u8),
    // UI state
    input_active: bool = false,
    input_buffer: [256]u8 = std.mem.zeroes([256]u8),
    input_len: usize = 0,
    // Submit form state
    tags_input_buffer: [256]u8 = std.mem.zeroes([256]u8),
    tags_input_len: usize = 0,
    tags_input_active: bool = false,
    submit_answer_selected: ?bool = null,
    // Per-question state
    response: QuestionResponse = QuestionResponse{ .question_id = "q001", .answer = null },
    selected: ?bool = null,
    // Input state tracking
    last_mouse_pressed: bool = false,
    last_touch_active: bool = false,
    // Loading state
    loading_message: [:0]const u8 = "Connecting to server...",
    // PRNG
    prng: std.Random.DefaultPrng = undefined,
    last_screen_width: i32 = 0,
    last_screen_height: i32 = 0,
};

// --- Question Pool ---
pub const question_pool = [_]Question{
    Question{ .id = "q001", .categories = &.{ "food", "meme" }, .difficulty = 2, .question = "Pizza is a vegetable?", .title = "Pizza Fact", .passage = "Some US lawmakers once argued that pizza counts as a vegetable in school lunches.", .answer = false },
    Question{ .id = "q002", .categories = &.{ "science", "nature" }, .difficulty = 1, .question = "The sky is blue?", .title = "Sky Color", .passage = "", .answer = true },
    Question{ .id = "q003", .categories = &.{"math"}, .difficulty = 1, .question = "2+2=5?", .title = "Math Check", .passage = "", .answer = false },
    Question{ .id = "q004", .categories = &.{ "science", "physics" }, .difficulty = 2, .question = "Water boils at 100C?", .title = "Boiling Point", .passage = "", .answer = true },
    Question{ .id = "q005", .categories = &.{ "animals", "meme" }, .difficulty = 1, .question = "Cats can fly?", .title = "Cat Fact", .passage = "", .answer = false },
    Question{ .id = "q006", .categories = &.{ "science", "geography" }, .difficulty = 2, .question = "Earth is round?", .title = "Earth Shape", .passage = "", .answer = true },
    Question{ .id = "q007", .categories = &.{"science"}, .difficulty = 1, .question = "Fire is cold?", .title = "Fire Fact", .passage = "", .answer = false },
    Question{ .id = "q008", .categories = &.{"animals"}, .difficulty = 1, .question = "Fish can swim?", .title = "Fish Fact", .passage = "", .answer = true },
    Question{ .id = "q009", .categories = &.{ "animals", "biology" }, .difficulty = 3, .question = "Birds are mammals?", .title = "Bird Fact", .passage = "", .answer = false },
    Question{ .id = "q010", .categories = &.{ "science", "geography" }, .difficulty = 2, .question = "Sun rises in the east?", .title = "Sunrise", .passage = "", .answer = true },
};

// --- JSON Types for API Response ---
pub const QuestionJSON = struct {
    id: []const u8,
    question: []const u8,
    title: []const u8 = "",
    passage: []const u8 = "",
    answer: bool,
    categories: [][]const u8 = &.{},
    difficulty: u8 = 3,

    pub fn toQuestion(self: QuestionJSON, allocator: std.mem.Allocator) !Question {
        // Use allocator to create proper null-terminated strings
        const id_copy = try allocator.dupeZ(u8, self.id);
        const question_copy = try allocator.dupeZ(u8, self.question);
        const title_copy = try allocator.dupeZ(u8, self.title);
        const passage_copy = try allocator.dupeZ(u8, self.passage);

        return Question{
            .id = id_copy,
            .question = question_copy,
            .title = title_copy,
            .passage = passage_copy,
            .answer = self.answer,
            .categories = &.{},
            .difficulty = self.difficulty,
        };
    }
};

pub const CategoryJSON = struct {
    name: []const u8,
    count: u32,
};

pub const APIResponseJSON = struct {
    questions: []QuestionJSON,
    count: u32,
    category: []const u8 = "general",
    difficulty: ?u8 = null,
    requested_count: u32,
    // Backwards compatibility
    tag: []const u8 = "general",
};

pub const CategoriesResponseJSON = struct {
    categories: []CategoryJSON,
    total_categories: u32,
};
