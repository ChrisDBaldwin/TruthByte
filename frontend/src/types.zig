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

pub const UserSessionResponse = struct {
    session_id: []const u8 = "",
    token: []const u8 = "",
    trust: f32 = 0.0,
    invitable: bool = false,
    responses: [7]QuestionResponse,
    timestamp: i64,
};

pub const GameStateEnum = enum { Authenticating, Loading, Answering, Submitting, Finished };

pub const Orientation = enum { Vertical, Horizontal };

pub const Question = struct {
    id: [:0]const u8, // Unique identifier
    tags: []const []const u8 = &.{}, // Tags/categories
    question: [:0]const u8, // The main question text
    title: [:0]const u8 = "", // Short label/headline (optional)
    passage: [:0]const u8 = "", // Supporting passage (optional)
    answer: bool, // True/False answer
};

pub const Session = struct {
    questions: [7]Question,
    current: usize = 0,
    correct: usize = 0,
    finished: bool = false,
};

pub const GameState = struct {
    // Palette and color state
    palettes: [NUM_PALETTES]Palette = undefined,
    bg_color: rl.Color = rl.Color{ .r = 200, .g = 215, .b = 235, .a = 255 },
    fg_color: rl.Color = rl.Color{ .r = 255, .g = 245, .b = 230, .a = 255 },
    // Game/session state
    game_state: GameStateEnum = .Authenticating,
    orientation: Orientation = .Vertical,
    auth_initialized: bool = false,
    session: Session = undefined,
    user_session: UserSessionResponse = UserSessionResponse{
        .responses = undefined,
        .timestamp = 0,
    },
    user_trust: f32 = 0.0,
    sessions_completed: u32 = 0,
    invited_shown: bool = false,
    loading_start_time: i64 = 0,
    // UI state
    input_active: bool = false,
    input_buffer: [256]u8 = undefined,
    input_len: usize = 0,
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
    Question{ .id = "q001", .tags = &.{ "food", "meme" }, .question = "Pizza is a vegetable?", .title = "Pizza Fact", .passage = "Some US lawmakers once argued that pizza counts as a vegetable in school lunches.", .answer = false },
    Question{ .id = "q002", .tags = &.{ "science", "nature" }, .question = "The sky is blue?", .title = "Sky Color", .passage = "", .answer = true },
    Question{ .id = "q003", .tags = &.{"math"}, .question = "2+2=5?", .title = "Math Check", .passage = "", .answer = false },
    Question{ .id = "q004", .tags = &.{ "science", "physics" }, .question = "Water boils at 100C?", .title = "Boiling Point", .passage = "", .answer = true },
    Question{ .id = "q005", .tags = &.{ "animals", "meme" }, .question = "Cats can fly?", .title = "Cat Fact", .passage = "", .answer = false },
    Question{ .id = "q006", .tags = &.{ "science", "geography" }, .question = "Earth is round?", .title = "Earth Shape", .passage = "", .answer = true },
    Question{ .id = "q007", .tags = &.{"science"}, .question = "Fire is cold?", .title = "Fire Fact", .passage = "", .answer = false },
    Question{ .id = "q008", .tags = &.{"animals"}, .question = "Fish can swim?", .title = "Fish Fact", .passage = "", .answer = true },
    Question{ .id = "q009", .tags = &.{ "animals", "biology" }, .question = "Birds are mammals?", .title = "Bird Fact", .passage = "", .answer = false },
    Question{ .id = "q010", .tags = &.{ "science", "geography" }, .question = "Sun rises in the east?", .title = "Sunrise", .passage = "", .answer = true },
};

// --- JSON Types for API Response ---
pub const QuestionJSON = struct {
    id: []const u8,
    question: []const u8,
    title: []const u8 = "",
    passage: []const u8 = "",
    answer: bool,
    tags: [][]const u8 = &.{},

    pub fn toQuestion(self: QuestionJSON, allocator: std.mem.Allocator) !Question {
        // Use allocator to create proper null-terminated strings
        const id_copy = try allocator.dupeZ(u8, self.id);
        const question_copy = try allocator.dupeZ(u8, self.question);
        const title_copy = try allocator.dupeZ(u8, self.title);
        const passage_copy = try allocator.dupeZ(u8, self.passage);

        std.debug.print("Converted question: '{s}'\n", .{question_copy});

        return Question{
            .id = id_copy,
            .question = question_copy,
            .title = title_copy,
            .passage = passage_copy,
            .answer = self.answer,
            .tags = &.{}, // TODO: Convert tags if needed
        };
    }
};

pub const APIResponseJSON = struct {
    questions: []QuestionJSON,
    count: u32,
    tag: []const u8 = "general",
    requested_count: u32,
};
