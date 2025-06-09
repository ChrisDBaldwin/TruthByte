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

🔵 **Frontend (WASM/Zig)**

- Renders a list of questions (statement + answer options) with associated tags for categorization (e.g., food, video games, Python, books).

- Tracks response times per question

- Posts results back to the backend with basic metadata

- Offers an optional "Submit your own question" flow

🟢 **Backend (Lambda)**
- GET /questions → returns a randomized batch of canary questions, optionally filtered by tags

- POST /answers → receives user answers + timing, computes trust score, and sends telemetry data to Honeycomb using OpenTelemetry

- POST /submit-question → saves user-submitted questions to a "pending" pool (S3, DynamoDB, or plain JSON)

- Integrates OpenTelemetry to monitor backend performance and send traces and metrics to Honeycomb

🟣 **Admin (you)**
- Can manually review pending questions and promote them to the main question set (or not)

- No moderation dashboard needed for now — just promote new questions manually

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
  "id": "q123",
  "text": "The moon is made of cheese.",
  "answer": false,
  "tags": ["science", "myth"]
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
