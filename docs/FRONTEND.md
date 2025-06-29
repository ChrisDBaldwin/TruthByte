# TruthByte Frontend Documentation

Complete guide to the TruthByte frontend: Zig → WASM game with full mobile support, optimized build system, and modular architecture.

## Architecture Overview

The frontend is built in **Zig** and compiles to **WebAssembly (WASM)** for web deployment, with native builds for development. The codebase is organized into a modular architecture for maintainability and development efficiency.

### Key Technologies
- **Zig Language**: Modern systems programming language
- **Raylib**: Cross-platform game development library
- **Emscripten**: Zig → WASM compilation toolchain
- **Custom Input System**: Unified mouse/touch/keyboard handling
- **Modular Architecture**: Separated concerns for easy maintenance

### Game Modes
- **Arcade Mode**: Classic 7-question sessions with category and difficulty selection
- **Categories Mode**: Browse and play questions from specific categories
  - Category filtering with question counts
  - Difficulty level selection (Easy, Medium, Hard)
  - Custom session lengths
- **Daily Mode**: **NEW** Daily challenge with 10 deterministic questions, streak tracking, and ranking system

### Build Targets
```
Zig Source Code
    ↓
├── Native Build (Development)
│   └── Fast iteration, hot reload
└── WASM Build (Production)  
    └── Web deployment, mobile optimized
```

## Project Structure

```
frontend/
├── src/
│   ├── main_release.zig      # WASM production entry point
│   ├── main_hot.zig          # Native development entry point
│   ├── game.zig              # Main game loop and coordination
│   ├── types.zig             # Type definitions and constants
│   ├── utils.zig             # Utilities and JavaScript interop
│   ├── input.zig             # Input handling system
│   ├── api.zig               # Network and API management
│   ├── render.zig            # UI rendering system
│   └── user.zig              # User identity and persistence management
├── build.zig                 # Zig build configuration
├── build.zig.zon             # Zig dependencies
├── shell.html                # WASM container HTML template
├── truthbyte_bindings.js     # JavaScript ↔ WASM interface
└── res/                      # Game resources/assets
```

## Modular Architecture

The frontend has been refactored from a single 1000+ line file into a clean modular structure:

### 🎯 Core Modules

#### `game.zig` - Main Game Loop
**Purpose**: High-level game coordination and exported API
```zig
// Clean main game loop
pub export fn init(allocator: *std.mem.Allocator) callconv(.C) *anyopaque;
pub export fn update(state: *types.GameState) callconv(.C) void;
pub export fn draw(state: *types.GameState) callconv(.C) void;
```

**Responsibilities**:
- Exported API functions for WASM/native
- High-level game state coordination
- Module orchestration
- **Game mode management** (Arcade, Categories, Daily)

#### `types.zig` - Type Definitions
**Purpose**: All type definitions, constants, and static data
```zig
// Core game types
pub const GameState = struct { /* ... */ };
pub const Question = struct { /* ... */ };
pub const Session = struct { /* ... */ };

// Layout constants
pub const LARGE_FONT_SIZE = 32;
pub const BUTTON_GAP = 40;
// ... all UI constants
```

**Contains**:
- `GameState` struct and all game types
- UI layout constants and dimensions
- Question pool and JSON response types
- Color definitions and palette types
- **Game mode enums** (`GameMode`, `GameStateEnum`)
- **Daily mode structures** (`DailyReview`, streak tracking data)
- **Category selection types** (`Category` struct with counts)

#### `utils.zig` - Utilities & Interop
**Purpose**: JavaScript interop and utility functions
```zig
// JavaScript bridge for WASM/native compatibility
pub const js = if (builtin.target.os.tag == .emscripten) struct {
    pub extern fn get_session_id() *const u8;
    pub extern fn fetch_questions(/* ... */) void;
    // ... other JavaScript functions
} else struct {
    // Native stubs
};

// Color and palette utilities
pub fn hslToRgb(h: f32, s: f32, l: f32) rl.Color;
pub fn initPalettes(state: *types.GameState) void;
```

**Responsibilities**:
- JavaScript function bindings (WASM) and stubs (native)
- Color manipulation and palette generation
- Canvas size utilities
- Game logic helpers
- **Daily mode utilities** (date formatting, score calculations)
- **Cross-platform compatibility** (native vs. WASM function stubs)

#### `input.zig` - Input Handling & Security
**Purpose**: Unified input system for mouse and touch with comprehensive security validation
```zig
pub const InputEvent = struct {
    pressed: bool,
    released: bool,
    position: rl.Vector2,
    source: enum { mouse, touch },
};

pub fn getInputEvent(state: *types.GameState) ?InputEvent;
pub fn handleTextInput(state: *types.GameState) void;
pub fn validateQuestionInput(question: []const u8, tags: []const u8) bool;
```

**Features**:
- Cross-platform touch/mouse input handling
- JavaScript coordinate mapping for mobile
- **Comprehensive input security validation**
- **Real-time malicious content detection**
- **Binary injection prevention**
- **XSS and code injection protection**
- Input sanitization and length limits
- Spam detection and rate limiting

**Security Architecture**:
- **Character Validation**: Only allows safe printable ASCII characters
- **Pattern Detection**: Blocks suspicious patterns like `<script>`, `javascript:`, `eval()`
- **Binary Content Blocking**: Prevents image data and binary injection
- **Length Limits**: Questions 10-200 chars, tags 1-50 chars, max 5 tags
- **Real-time Protection**: Malicious content triggers immediate field clearing
- **Multi-layer Defense**: Frontend validation backed by server-side verification

#### `api.zig` - Network & API
**Purpose**: All network operations and API management
```zig
// Session management
pub fn startAuthentication(state: *types.GameState) void;
pub fn startSession(state: *types.GameState) void;
pub fn submitResponseBatch(user_session_response: *types.UserSessionResponse) void;

// Callback functions
export fn on_auth_complete(success: i32) callconv(.C) void;
export fn on_questions_received(success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void;
```

**Responsibilities**:
- Authentication flow management
- API callback functions
- JSON parsing and session initialization
- Error handling and fallback logic
- **Daily mode API integration** (`fetch_daily_questions`, `submit_daily_answers`)
- **User data management** (streak tracking, daily progress)
- **Category management** (fetching available categories with counts)

#### `render.zig` - UI Rendering
**Purpose**: Complete UI rendering system
```zig
// Layout calculation system
pub const UILayout = struct { /* all UI rectangles and positions */ };
pub fn calculateLayout() UILayout;

// State-specific rendering
pub fn drawLoadingScreen(state: *types.GameState, layout: UILayout) void;
pub fn drawAnsweringScreen(state: *types.GameState, layout: UILayout) void;
pub fn drawFinishedScreen(state: *types.GameState, layout: UILayout) void;

// Main draw function
pub fn draw(state: *types.GameState) void;
```

**Features**:
- Modular rendering for each game state
- Automatic layout calculation
- Responsive UI positioning
- Easy to modify for UI redesigns
- **Mode selection screen** with three game mode buttons
- **Daily mode review screen** with score, rank, and streak display
- **Category browsing interface** with category counts and difficulty filters

#### `user.zig` - User Identity Management
**Purpose**: Persistent user identity and localStorage integration
```zig
// User ID management
pub fn initUserID(prng: *std.Random.DefaultPrng) void;
pub fn getUserID() [:0]const u8;
pub fn getUserIDSlice() []const u8;
pub fn resetUserID() void;

// Internal UUID generation
fn generateUUID(prng: *std.Random.DefaultPrng) [36]u8;
```

**Features**:
- **Cryptographically secure UUID v4 generation** using Zig's PRNG
- **Persistent storage** via localStorage with minimal JavaScript interface
- **Type-safe API** for user ID management across the application

## Daily Mode Features (NEW)

The frontend now includes a comprehensive daily mode system with the following features:

### **Game Flow**
1. **Mode Selection**: Choose between Arcade, Categories, or Daily mode
2. **Daily Challenge**: 10 deterministic questions, same for all users each day
3. **Score Calculation**: Real-time scoring with letter grades (S, A, B, C, D)
4. **Streak Tracking**: Daily streaks with performance requirements (≥70% for continuation)
5. **Progress Review**: Detailed results screen with score breakdown and rank display

### **Daily Mode UI Components**
- **Mode Selection Screen**: Three-button interface for game mode selection
- **Daily Review Screen**: Score display with letter rank, correct/total counts, and streak information
- **Progress Indicators**: Visual representation of daily completion status
- **Streak Display**: Current and best streak counters with continuation status

### **Technical Implementation**
- **Deterministic Questions**: Same 10 questions for all users on a given date
- **Client-side Score Calculation**: Real-time scoring feedback during gameplay  
- **Persistent State**: Daily completion status stored and validated server-side
- **Cross-platform Compatibility**: Full mobile and desktop support

### **User Experience Features**
- **One Daily Challenge**: Prevents multiple attempts per day
- **Performance Ranking**: Letter grades based on percentage correct
- **Streak Motivation**: Visual streak counters encourage daily participation
- **Immediate Feedback**: Instant score and rank display upon completion
- **Cross-platform support** (web and native builds)
- **Automatic initialization** during game startup

**Architecture**:
- Generates UUID v4 compliant identifiers with proper version and variant bits
- Stores user ID in browser localStorage for persistence across sessions
- Provides clean Zig interface that eliminates JavaScript scoping issues
- Used by all API calls to include `X-User-ID` header for backend user tracking

### 📁 Module Dependencies
```
game.zig
├── types.zig     (type definitions)
├── utils.zig     (utilities & JS interop)
├── input.zig     (input handling)
├── api.zig       (network operations)
├── render.zig    (UI rendering)
│   └── types.zig & utils.zig
└── user.zig      (user identity management)
    └── used by api.zig and game.zig
```

### 🎨 Benefits of Modular Architecture

1. **Maintainability**: Each module has a single, clear responsibility
2. **UI Development**: All rendering logic isolated for easy redesign
3. **Testing**: Individual modules can be unit tested
4. **Parallel Development**: Different team members can work on different modules
5. **Code Navigation**: Easy to find and modify specific functionality
6. **Reusability**: Modules can be reused in other projects

## Build System

### Prerequisites
- **Zig**: Version 0.14.0+ ([Download](https://ziglang.org/download/))
- **Emscripten SDK**: For WASM builds ([Setup Guide](https://emscripten.org/docs/getting_started/downloads.html))
- **EMSDK Environment Variable**: Must be set for WASM compilation

### Environment Setup

#### EMSDK Installation
```bash
# Clone Emscripten SDK
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk

# Install and activate
./emsdk install latest
./emsdk activate latest

# Set environment variable
export EMSDK=/path/to/your/emsdk  # Unix/macOS
$env:EMSDK="C:\path\to\emsdk"     # Windows PowerShell
```

### Development Build (Native)
Fast iteration with hot reload:
```bash
cd frontend
zig build run
```

**Features:**
- **Native Performance**: No WASM overhead
- **Hot Reload**: Automatic rebuilds
- **Debug Support**: Full debugging capabilities
- **Cross-Platform**: Works on Windows, macOS, Linux

### Production Build (WASM)
Optimized web deployment:
```bash
cd frontend
zig build -Dtarget=wasm32-emscripten run
```

**Features:**
- **Web Compatible**: Runs in any modern browser
- **Mobile Optimized**: Touch input and responsive design
- **Size Optimized**: Minimal WASM binary
- **Release Performance**: Fast execution

## Mobile Support

### Touch Input System
The frontend includes a comprehensive touch input system for mobile devices:

#### JavaScript Bridge
```javascript
// Custom coordinate capture for raylib-zig WASM compatibility
function setupTouchHandling() {
    canvas.addEventListener('touchstart', handleTouch);
    canvas.addEventListener('touchend', handleTouch);
    canvas.addEventListener('touchmove', handleTouch);
}
```

#### Zig Input Processing
```zig
// Unified input event handling in input.zig
const InputEvent = struct {
    pressed: bool,
    released: bool,
    position: rl.Vector2,
    source: enum { mouse, touch },
};

pub fn getInputEvent(state: *types.GameState) ?InputEvent {
    // Handle mouse, touch, and keyboard events uniformly
    // Cross-platform coordinate mapping
    // JavaScript integration for mobile browsers
}
```

### iOS Safari Optimizations
Special handling for iOS Safari quirks:
```html
<!-- Prevent zoom and bounce scrolling -->
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  body { 
    touch-action: manipulation;
    -webkit-touch-callout: none;
  }
</style>
```

### Visual Viewport API
Proper handling of mobile browser UI changes:
```javascript
// Handle mobile keyboard and browser UI
if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', updateCanvasSize);
}
```

### Supported Devices
- ✅ **iPhone**: Chrome, Safari (including iOS Safari)
- ✅ **Android**: Chrome, Firefox, Samsung Internet
- ✅ **iPad**: Chrome, Safari
- ✅ **Desktop**: All modern browsers

## Game Architecture

### State Management
```zig
// Defined in types.zig
const GameStateEnum = enum {
    Authenticating,  // JWT token acquisition
    Loading,         // Question loading
    Answering,       // User answering questions
    Submitting,      // Sending answers to backend
    Finished,        // Session complete
};
```

### Core Game Loop
```zig
// In game.zig - clean and focused
pub export fn update(state: *types.GameState) callconv(.C) void {
    // Canvas size management
    const size = utils.get_canvas_size();
    
    // Input handling
    if (input.getInputEvent(state)) |input_event| {
        // Process UI interactions
    }
    
    // Text input processing
    input.handleTextInput(state);
    
    // Game logic updates
}

pub export fn draw(state: *types.GameState) callconv(.C) void {
    render.draw(state);  // Delegate to render module
}
```

### State-Specific Rendering
```zig
// In render.zig - modular and organized
pub fn draw(state: *types.GameState) void {
    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(state.bg_color);

    const layout = calculateLayout();

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
```

### Authentication Integration
```zig
// In api.zig - centralized API management
pub fn startAuthentication(state: *types.GameState) void {
    state.game_state = .Authenticating;
    state.loading_message = "Connecting to server...";

    if (builtin.target.os.tag == .emscripten) {
        utils.js.init_auth(on_auth_complete);
    } else {
        // Native build fallback
        state.auth_initialized = true;
        startSession(state);
    }
}

export fn on_auth_complete(success: i32) callconv(.C) void {
    if (g_state == null) return;
    const state = g_state.?;

    if (success == 1) {
        state.auth_initialized = true;
        startSession(state);
    } else {
        state.loading_message = "Authentication failed. Using offline mode.";
        initSessionWithFallback(state);
    }
}
```

## JavaScript ↔ WASM Interface

### API Functions
```javascript
// Authentication
function init_auth(callback) {
    fetch('/v1/session')
        .then(response => response.json())
        .then(data => {
            window.jwt_token = data.token;
            window.session_id = data.session_id;
            Module._call_callback(callback, true);
        })
        .catch(() => Module._call_callback(callback, false));
}

// Authenticated API requests
function _fetchWithAuth(url, options = {}) {
    return fetch(url, {
        ...options,
        headers: {
            'Authorization': `Bearer ${window.jwt_token}`,
            'Content-Type': 'application/json',
            ...options.headers
        }
    });
}
```

### Zig Extern Declarations
```zig
// In utils.zig - centralized JavaScript interop
pub const js = if (builtin.target.os.tag == .emscripten) struct {
    pub extern fn get_session_id() *const u8;
    pub extern fn get_session_id_len() usize;
    pub extern fn get_token() *const u8;
    pub extern fn get_token_len() usize;
    pub extern fn get_canvas_width() i32;
    pub extern fn get_canvas_height() i32;
    pub extern fn fetch_questions(num_questions: i32, tag_ptr: ?[*]const u8, tag_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;
    pub extern fn submit_answers(json_ptr: [*]const u8, json_len: usize, callback_ptr: *const fn (success: i32, data_ptr: [*]const u8, data_len: usize) callconv(.C) void) void;
    // ... other functions
} else struct {
    // Native build stubs for all functions
};
```

## Build Configuration

### build.zig Structure
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Native executable
    const exe = b.addExecutable(.{
        .name = "truthbyte",
        .root_source_file = .{ .path = "src/main_hot.zig" },
        .target = target,
        .optimize = optimize,
    });

    // WASM executable  
    const wasm_exe = b.addExecutable(.{
        .name = "truthbyte",
        .root_source_file = .{ .path = "src/main_release.zig" },
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .emscripten,
        }),
        .optimize = .ReleaseFast,
    });
}
```

### Dependencies (build.zig.zon)
```zig
.{
    .name = "truthbyte-frontend",
    .version = "0.1.0",
    .dependencies = .{
        .raylib = .{
            .url = "https://github.com/raysan5/raylib/archive/refs/tags/5.0.tar.gz",
            .hash = "...",
        },
    },
}
```

## UI Development Guide

### Adding New UI Elements

With the modular architecture, UI modifications are straightforward:

#### 1. Update Layout (render.zig)
```zig
// Add to UILayout struct
pub const UILayout = struct {
    // ... existing fields
    new_button_rect: rl.Rectangle,
};

// Update calculateLayout function
pub fn calculateLayout() UILayout {
    // ... existing calculations
    const new_button_rect = rl.Rectangle{
        .x = @as(f32, @floatFromInt(screen_width - 100)),
        .y = @as(f32, @floatFromInt(50)),
        .width = 80,
        .height = 40,
    };
    
    return UILayout{
        // ... existing fields
        .new_button_rect = new_button_rect,
    };
}
```

#### 2. Add Rendering (render.zig)
```zig
pub fn drawAlwaysVisibleUI(state: *types.GameState, layout: UILayout) void {
    // ... existing UI elements
    
    // New button
    rl.drawRectangleRec(layout.new_button_rect, types.accent);
    rl.drawText("NEW", @as(i32, @intFromFloat(layout.new_button_rect.x)) + 10, 
                @as(i32, @intFromFloat(layout.new_button_rect.y)) + 10, 
                types.SMALL_FONT_SIZE, rl.Color.white);
}
```

#### 3. Handle Input (game.zig)
```zig
pub export fn update(state: *types.GameState) callconv(.C) void {
    // ... existing code
    
    if (input.getInputEvent(state)) |input_event| {
        if (!input_event.pressed) return;
        
        const pos = input_event.position;
        const layout = render.calculateLayout();
        
        // ... existing button checks
        
        if (rl.checkCollisionPointRec(pos, layout.new_button_rect)) {
            // Handle new button click
            handleNewButtonClick(state);
        }
    }
}
```

#### 4. Add Constants (types.zig)
```zig
// Add new UI constants if needed
pub const NEW_BUTTON_WIDTH = 80;
pub const NEW_BUTTON_HEIGHT = 40;
```

### Theming and Colors

All color management is centralized in `utils.zig`:

```zig
// Modify palette generation
pub fn initPalettes(state: *types.GameState) void {
    var i: usize = 0;
    while (i < types.NUM_PALETTES) : (i += 1) {
        const bg_hue = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(types.NUM_PALETTES));
        const fg_hue = @mod(bg_hue + 0.5, 1.0);
        state.palettes[i] = types.Palette{
            .bg = hslToRgb(bg_hue, 0.6, 0.15),  // Increased saturation
            .fg = hslToRgb(fg_hue, 0.5, 0.85),  // Adjusted lightness
        };
    }
}
```

## Deployment

### Automated Deployment
The frontend is deployed via automated scripts:

```bash
# Full deployment with CloudFront CDN
./deploy/scripts/deploy-frontend.sh \
  --bucket-name your-domain.com \
  --certificate-id YOUR_ACM_CERT_ID

# PowerShell (Windows)
.\deploy\scripts\deploy-frontend.ps1 `
  -BucketName your-domain.com `
  -CertificateId YOUR_ACM_CERT_ID
```

### Build Artifacts
Generated in `deploy/artifacts/frontend/`:
```
index.html    # Optimized HTML shell
index.js      # Emscripten-generated JavaScript  
index.wasm    # Compiled WebAssembly binary
```

### CDN Configuration
- **S3 Hosting**: Static website hosting
- **CloudFront**: Global CDN with HTTPS
- **Cache Strategy**:
  - HTML: `no-cache` (always fresh)
  - Assets: `max-age=3600` (1 hour cache)

## Performance Optimization

### Build Optimizations
- **ReleaseFast**: Maximum runtime performance
- **Link-Time Optimization**: Cross-module optimization
- **Modular Compilation**: Only recompile changed modules

### Runtime Optimizations
- **60 FPS Target**: Smooth animation and interaction
- **Efficient Rendering**: Minimal draw calls
- **Memory Management**: Stack allocation preferred
- **Canvas Optimization**: Proper size and scaling

### Mobile Optimizations
- **Touch Debouncing**: Prevent accidental double-taps
- **Responsive Scaling**: Automatic canvas resizing
- **Battery Efficiency**: Optimized frame rate management

## Debugging

### Development Tools
```bash
# Native build with debug info
zig build -Doptimize=Debug run

# WASM build with debug symbols
zig build -Dtarget=wasm32-emscripten -Doptimize=Debug run
```

### Module-Specific Debugging
```zig
// In each module, add debug logging:
const std = @import("std");

pub fn debugLog(comptime message: []const u8, args: anytype) void {
    if (builtin.mode == .Debug) {
        std.debug.print("[MODULE_NAME] " ++ message ++ "\n", args);
    }
}
```

### Browser Debugging
- **Chrome DevTools**: Source maps for Zig debugging
- **Console Logging**: JavaScript bridge debug info
- **Network Tab**: API request/response inspection
- **Performance Tab**: WASM execution profiling

### Debug Controls
- **Press 'P'**: Test authentication ping
- **Press 'R'**: Reset game state
- **Browser Console**: Detailed logging output

## Common Issues

### Build Issues
1. **EMSDK not found**: Set `EMSDK` environment variable
2. **Zig version**: Ensure 0.14.0+ is installed
3. **Dependencies**: Run `zig build --fetch` to download deps
4. **Module errors**: Check import paths in each module

### Runtime Issues
1. **Touch not working**: Check `input.zig` coordinate mapping
2. **WASM load failure**: Verify MIME types on server
3. **Auth failures**: Check `api.zig` callback functions
4. **Performance**: Monitor browser console for errors
5. **Rendering issues**: Check `render.zig` layout calculations

## Security Constraints

The frontend implements comprehensive security measures to ensure safe user input and prevent malicious content:

### Input Validation Rules
```
Question Input:
- Length: 5-200 characters
- Content: Printable ASCII + basic punctuation
- Pattern blocking: <script>, javascript:, eval(), etc.
- Binary content detection and blocking

Tag Input:
- Individual tag length: Max 50 characters
- Total tags length: Max 150 characters
- Allowed chars: Letters, numbers, spaces, hyphens, underscores
- Maximum 5 tags per question
```

### Security Features
- **Real-time Validation**: Immediate clearing of malicious content
- **Pattern Detection**: Blocks suspicious code patterns and injection attempts
- **Input Sanitization**: Removes unsafe characters and excessive whitespace
- **Length Limits**: Enforced on both client and server side
- **Binary Prevention**: Detects and blocks non-text content
- **XSS Protection**: Comprehensive blocking of script injection attempts

## Error Handling and Offline Support

The frontend implements robust error handling and offline capabilities:

### Authentication and Network
- **Auth Timeout**: 10-second timeout with graceful degradation
- **Connection Messages**: 
  - "Connecting to server..."
  - "Still connecting..." (after 5s)
  - "Connection timeout. Using offline mode." (after 10s)
- **Manual Fallback**: Tap-to-skip after 8 seconds

### Offline Mode
- **Automatic Fallback**: Switches to offline mode on connection failure
- **Available Features**:
  - Local question pool
  - Basic game modes
  - Score tracking
  - Daily mode (limited functionality)
- **State Management**:
  - Resets streak counters
  - Maintains local progress
  - Preserves user preferences

### Error Recovery
- **Network Errors**: Graceful fallback to offline mode
- **Data Parsing**: Safe handling of malformed responses
- **State Recovery**: Maintains game progress during errors
- **User Feedback**: Clear error messages and status updates

## User Data Management

The frontend implements a comprehensive user data management system:

### Streak Tracking
- **Current Streak**: Tracks consecutive daily completions
- **Best Streak**: Records highest achieved streak
- **Streak Requirements**: 70% correct answers to maintain streak

### Progress Persistence
- **Daily Progress**: Tracks completion status per day
- **Answer History**: Records user responses and timing
- **Category Progress**: Tracks performance by category

### Statistics
- **Score History**: Maintains record of past performances
- **Category Stats**: Tracks success rates by category
- **Time Analysis**: Records answer timing data
- **Difficulty Stats**: Tracks performance across difficulty levels
