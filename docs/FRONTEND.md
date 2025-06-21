# TruthByte Frontend Documentation

Complete guide to the TruthByte frontend: Zig → WASM game with full mobile support and optimized build system.

## Architecture Overview

The frontend is built in **Zig** and compiles to **WebAssembly (WASM)** for web deployment, with native builds for development.

### Key Technologies
- **Zig Language**: Modern systems programming language
- **Raylib**: Cross-platform game development library
- **Emscripten**: Zig → WASM compilation toolchain
- **Custom Input System**: Unified mouse/touch/keyboard handling

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
│   └── game.zig              # Core game logic and UI
├── build.zig                 # Zig build configuration
├── build.zig.zon             # Zig dependencies
├── shell.html                # WASM container HTML template
├── truthbyte_bindings.js     # JavaScript ↔ WASM interface
└── res/                      # Game resources/assets
```

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
// Unified input event handling
const InputEvent = struct {
    type: InputType,
    x: f32,
    y: f32,
    pressed: bool,
};

pub fn processInput() InputEvent {
    // Handle mouse, touch, and keyboard events uniformly
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
const GameState = enum {
    Authenticating,  // JWT token acquisition
    Loading,         // Question loading
    Answering,       // User answering questions
    Submitting,      // Sending answers to backend
    Finished,        // Session complete
};
```

### Core Game Loop
```zig
pub fn update(state: *GameState) void {
    switch (state.current_state) {
        .Authenticating => updateAuthentication(state),
        .Loading => updateLoading(state),
        .Answering => updateAnswering(state),
        .Submitting => updateSubmitting(state),
        .Finished => updateFinished(state),
    }
}

pub fn draw(state: *GameState) void {
    rl.beginDrawing();
    defer rl.endDrawing();
    
    switch (state.current_state) {
        .Authenticating => drawAuthenticating(state),
        .Loading => drawLoading(state),
        .Answering => drawAnswering(state),
        .Submitting => drawSubmitting(state),
        .Finished => drawFinished(state),
    }
}
```

### Authentication Integration
```zig
pub fn startAuthentication(state: *GameState) void {
    // Call JavaScript authentication
    js.init_auth(on_auth_complete);
    state.auth_message = "Connecting to server...";
}

export fn on_auth_complete(success: bool) void {
    if (success) {
        // Proceed to question loading
        global_state.auth_initialized = true;
        startSession(global_state);
    } else {
        // Fall back to offline mode
        useOfflineQuestions(global_state);
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
// JavaScript function imports
extern fn init_auth(callback: fn(bool) callconv(.C) void) void;
extern fn auth_ping() void;
extern fn get_token() [*:0]const u8;
extern fn get_session_id() [*:0]const u8;
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
- **Dead Code Elimination**: Unused code removal
- **Link-Time Optimization**: Cross-module optimization

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

### Runtime Issues
1. **Touch not working**: Check JavaScript coordinate mapping
2. **WASM load failure**: Verify MIME types on server
3. **Auth failures**: Check JWT token and API endpoints
4. **Performance**: Monitor browser console for errors

### Mobile Issues
1. **iOS Safari zoom**: Verify viewport meta tag
2. **Android keyboard**: Check Visual Viewport API handling
3. **Touch coordinates**: Verify canvas coordinate conversion

---

**Last Updated**: Current as of latest frontend build  
**Version**: 1.0.0 