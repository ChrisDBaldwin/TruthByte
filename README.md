# TruthByte

A minimal Zig+WASM game that crowdsources human truth judgments to build better LLM evaluation datasets. Play a fast round of "True or False?" — every answer trains the future.

## Proof of Concept

### Core Assumptions

- All questions have a canonical "true" answer known to the system
- Users answer batches of questions (maybe 5–10)
- Each session is tagged with simple metadata (IP hash, timestamp, optional fingerprint)
- A User's trust score is calculated but doesn't block interaction yet
- Users can optionally submit questions for potential inclusion

### System Components

🟢 **Frontend (WASM/Zig) — Working**

- Compiles to WASM and renders the quiz UI in the browser
- Loads questions, displays passages, and tracks response times per question
- Makes API calls to the backend for fetching questions and submitting answers (API endpoints are stubs and pending)
- User session tracking is planned (currently commented out)
- Optional "Submit your own question" flow is planned

🟡 **Backend (Zig) — In Progress**

- Project initialized (`zig init`), but endpoints are not yet implemented
- Will provide:
  - `GET /questions` → returns a randomized batch of questions, optionally filtered by tags
  - `POST /answers` → receives user answers + timing, computes trust score, and sends telemetry data
  - `POST /submit-question` → saves user-submitted questions to a pending pool
  - `POST /suggest-tags` and `POST /remove-tags` → endpoints for suggesting tag additions/removals (planned)
- Will integrate OpenTelemetry and support S3/DynamoDB/JSON storage (planned)

🟠 **Admin (Manual Review) — Manual Process**

- No moderation dashboard yet
- To promote a question: manually move it from the pending pool to the main question set (e.g., by editing a JSON file or running a script)
- To reject a question: manually delete or archive it from the pending pool
- Tag suggestions and removals are handled by backend endpoints (planned), but can also be done by editing the data files directly

---

**Legend:**
- 🟢 Working/Implemented
- 🟡 In Progress/Planned
- 🟠 Manual/Requires Admin Action

### Data Flow Summary
```
User → Frontend (WASM) → GET /questions
                           ↑
     ↓ answers w/ timing  → POST /answers
     ↓ new question       → POST /submit-question
```

### Example Data Structures

#### Questions

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

#### User Submission

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

#### User Question Submission

```json
{
  "text": "Water boils at 100°C at sea level.",
  "answer": true,
  "tags": ["science", "physics"],
  "submitted_at": 1685939231
}
```

## Repo Template

I am using a template from https://github.com/Lommix/zig-raylib-wasm-hot-template for zig + raylib + wasm


## Data

Questions were sourced from BoolQ's Dataset (thanks Amol & Kenton)
https://github.com/google-research-datasets/boolean-questions
