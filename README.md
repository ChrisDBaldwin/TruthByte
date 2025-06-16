# TruthByte

A minimal Zig+WASM game that crowdsources human truth judgments to build better LLM evaluation datasets. Play a fast round of "True or False?" — every answer trains the future.

**🎮 [Play Now: truthbyte.voidtalker.com](https://truthbyte.voidtalker.com)**

## Table of Contents
- [Quick Start](#quick-start)
- [Project Overview](#project-overview)
  - [Core Assumptions](#core-assumptions)
  - [System Components](#system-components)
  - [Data Flow](#data-flow)
- [Mobile & Touch Support](#mobile--touch-support)
- [Development Guide](#development-guide)
  - [Prerequisites](#prerequisites)
  - [Environment Setup](#environment-setup)
    - [EMSDK Installation](#emsdk-installation)
    - [Environment Variables](#environment-variables)
  - [Building and Running](#building-and-running)
- [Deployment](#deployment)
- [Data Structures](#data-structures)
  - [Questions](#questions)
  - [User Submission](#user-submission)
  - [User Question Submission](#user-question-submission)
- [Technical Details](#technical-details)
  - [Repo Template](#repo-template)
  - [Data Sources](#data-sources)

## Quick Start

1. **Clone and Setup**:
```bash
git clone https://github.com/yourusername/truthbyte.git
cd truthbyte
```

2. **Install Prerequisites**:
- Zig (0.14.0+)
- Python 3.13.5+
- EMSDK (for WASM)

3. **Set EMSDK**:
```bash
# Windows PowerShell
$env:EMSDK="C:\path\to\emsdk"

# Unix/macOS
export EMSDK=/path/to/emsdk
```

4. **Run Frontend**:
```bash
cd frontend
zig build -Dtarget=wasm32-emscripten run
```

For detailed setup instructions, see the [Development Guide](#development-guide).

## Project Overview

### Core Assumptions

- All questions have a canonical "true" answer known to the system
- Users answer batches of questions (maybe 5–10)
- Each session is tagged with simple metadata (IP hash, timestamp, optional fingerprint)
- A User's trust score is calculated but doesn't block interaction yet
- Users can optionally submit questions for potential inclusion

### System Components

🟢 **Frontend (WASM/Zig) — Working**
- Compiles to WASM and renders the quiz UI in the browser
- **Full mobile touch support** with iOS Safari optimizations
- Loads questions, displays passages, and tracks response times per question
- Makes API calls to the backend for fetching questions and submitting answers
- **Cross-platform input system** supporting mouse, touch, and keyboard
- User session tracking is planned (currently commented out)
- Optional "Submit your own question" flow is planned

🟡 **Backend (Python) — In Progress**
- Project initialized, endpoints pending implementation
- Provides:
  - `GET /fetch-questions` → returns a randomized batch of questions, optionally filtered by tags
  - `POST /answers` → receives user answers + timing, computes trust score
  - `POST /submit-question` → saves user-submitted questions to a pending pool
  - `POST /suggest-tags` and `POST /remove-tags` → tag management endpoints (planned)
- Will integrate OpenTelemetry and support S3/DynamoDB/JSON storage

🟠 **Admin (Manual Review) — Manual Process**
- No moderation dashboard yet
- Manual question promotion/rejection process
- Tag management through backend endpoints or direct data file edits

### Data Flow

```
User → Frontend (WASM) → GET /questions
                           ↑
     ↓ answers w/ timing  → POST /answers
     ↓ new question       → POST /submit-question
```

## Mobile & Touch Support

TruthByte is fully optimized for mobile devices with comprehensive touch input support:

### Features
- **Universal Input System**: Unified handling of mouse, touch, and keyboard events
- **Mobile-First UI**: Responsive design that adapts to all screen sizes
- **iOS Safari Optimizations**: Prevents zoom, bounce scrolling, and touch callouts
- **Visual Viewport API**: Proper handling of mobile browser UI changes
- **Touch Event Prevention**: Prevents default browser behaviors that interfere with gameplay

### Technical Implementation
- **JavaScript Touch Workaround**: Custom coordinate capture system to work around raylib-zig WASM limitations
- **Canvas Coordinate Mapping**: Accurate touch-to-canvas coordinate conversion
- **Cross-Platform Build System**: Separate native (`main_hot.zig`) and web (`main_release.zig`) builds
- **Input State Tracking**: Proper press/release event handling for UI interactions

### Supported Devices
- ✅ iPhone (Chrome, iOS Safari)
- ✅ Android (Chrome, Firefox)
- ✅ iPad (Chrome, Safari)
- ✅ Desktop (Chrome, Firefox, Safari, Edge)

## Development Guide

### Prerequisites

- Zig (latest, or 0.14.0+)
- Python 3.13.5+ (for backend)
- Emscripten SDK (EMSDK) for WASM compilation

### Environment Setup

#### EMSDK Installation

1. Clone the Emscripten SDK:
```bash
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
```

2. Install and activate the latest version:
```bash
# Windows
./emsdk.bat install latest
./emsdk.bat activate latest

# Unix/macOS
./emsdk install latest
./emsdk activate latest
```

#### Environment Variables

1. **Temporary Setup**:
```bash
# Windows PowerShell
$env:EMSDK="path/to/your/emsdk"  # e.g., "C:\code\git\emsdk"

# Windows CMD
set EMSDK=path/to/your/emsdk

# Unix/macOS
export EMSDK=/path/to/your/emsdk
```

2. **Permanent Setup**:

Windows:
1. Open System Properties (Win + Break)
2. Click "Environment Variables"
3. Under "System Variables", click "New"
4. Variable name: `EMSDK`
5. Variable value: Your EMSDK path (e.g., `C:\path\to\emsdk`)

macOS/Linux:
Add to your shell's startup file (`~/.bashrc`, `~/.zshrc`, etc.):
```bash
export EMSDK=/path/to/your/emsdk
export PATH=$EMSDK:$PATH
```

3. **Verify Setup**:
```bash
# Should print your EMSDK path
echo %EMSDK%  # Windows CMD
echo $EMSDK   # PowerShell/Unix

# Should show emcc version
emcc --version
```

### Building and Running

#### Frontend (WASM)
1. Navigate to the frontend directory:
```bash
cd frontend
```

2. **Development Build** (with hot-reload):
```bash
zig build run
```

3. **Production Build** (WASM for deployment):
```bash
zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseFast
```

4. **Test Local Web Build**:
```bash
# Build for web
zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseFast

# Serve locally (Python)
python -m http.server 8000

# Open http://localhost:8000/zig-out/htmlout/index.html

```

This will:
- Compile the Zig code to WebAssembly
- Generate optimized WASM, JS, and HTML files
- Enable testing of the actual deployed version locally

If you encounter the error `EMSDK environment variable not found`, ensure you've set up the EMSDK environment variable as described above.

## Deployment

TruthByte uses automated deployment scripts for AWS infrastructure:

### Frontend Deployment
```bash
# Deploy to S3 with CloudFront
cd deploy
./scripts/deploy-frontend.sh --bucket-name truthbyte.yourdomain.com --certificate-id YOUR_CERT_ID

# PowerShell (Windows)
.\scripts\deploy-frontend.ps1 -BucketName truthbyte.yourdomain.com -CertificateId YOUR_CERT_ID
```

### Features
- **Automated S3 Setup**: Creates bucket with static website hosting
- **CloudFront Integration**: Automatic CDN setup with HTTPS
- **Optimized Caching**: Proper cache-control headers for web assets
- **Cross-Platform Scripts**: Both Bash and PowerShell support

See [deploy/README.md](deploy/README.md) for detailed deployment instructions.

## Data Structures

### Questions

```json
{
  "id": "q003",
  "tags": ["health"],
  "question": "is pain experienced in a missing body part or paralyzed area",
  "title": "Phantom pain",
  "passage": "Phantom pain sensations are described as perceptions that an individual experiences relating to a limb or an organ that is not physically part of the body. Limb loss is a result of either removal by amputation or congenital limb deficiency. However, phantom limb sensations can also occur following nerve avulsion or spinal cord injury.",
  "answer": true
}
```

### User Submission

```json
{
  "session_id": "abc123",
  "responses": [
    { "question_id": "q123", "answer": false, "duration": 3.2 },
    { "question_id": "q456", "answer": true,  "duration": 1.7 }
  ],
  "timestamp": 1685939231,
  "ip_hash": "84d5ae...",
  "user_agent": "wasm-frontend-1"
}
```

### User Question Submission

```json
{
  "text": "Water boils at 100°C at sea level.",
  "answer": true,
  "tags": ["science", "physics"],
  "submitted_at": 1685939231
}
```

## Technical Details

### Repo Template

This project uses a template from [zig-raylib-wasm-hot-template](https://github.com/Lommix/zig-raylib-wasm-hot-template) for zig + raylib + wasm integration.

### Data Sources

Questions were sourced from BoolQ's Dataset (thanks Amol & Kenton)
https://github.com/google-research-datasets/boolean-questions
