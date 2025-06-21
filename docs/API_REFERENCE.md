# TruthByte API Reference

Complete reference for all TruthByte API endpoints, authentication, and data models.

## Base URL

- **Production**: `https://api.truthbyte.voidtalker.com/v1`
- **Development**: Determined by CloudFormation stack deployment

## Authentication

All protected endpoints require JWT authentication via Bearer token.

### Getting a Token

```http
GET /session
```

**Response:**
```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "session_id": "demo-session-123",
  "expires_in": 43200
}
```

### Using Tokens

Include the JWT token in the Authorization header:

```http
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
```

## Endpoints

### 🔓 Public Endpoints

#### GET `/session`
**Purpose**: Generate JWT session token  
**Authentication**: None required  
**Parameters**: None

**Response:**
```json
{
  "token": "string",
  "session_id": "string", 
  "expires_in": 43200
}
```

### 🔒 Protected Endpoints

All endpoints below require JWT authentication.

#### GET `/fetch-questions`
**Purpose**: Retrieve randomized questions by tag  
**Authentication**: Bearer token required

**Query Parameters:**
- `tag` (optional): Category filter (default: "general")
- `count` (optional): Number of questions (default: 5, max: 10)

**Example Request:**
```http
GET /fetch-questions?tag=science&count=7
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
```

**Response:**
```json
{
  "questions": [
    {
      "id": "q001",
      "question": "Does ethanol take more energy to make than it produces?",
      "title": "Ethanol fuel energy balance",
      "passage": "All biomass goes through at least some of these steps...",
      "answer": false,
      "tags": ["science", "energy", "general"]
    }
  ],
  "count": 1,
  "tag": "science",
  "requested_count": 7
}
```

#### POST `/submit-answers`
**Purpose**: Submit user answers and receive trust score  
**Authentication**: Bearer token required

**Request Body:**
```json
{
  "answers": [
    {
      "user_id": "string",
      "question_id": "string",
      "answer": boolean,
      "timestamp": number,
      "response_time_ms": number
    }
  ]
}
```

**Response:**
```json
{
  "message": "Answers submitted successfully",
  "trust_score": 0.85,
  "correct_answers": 4,
  "total_answers": 5
}
```

#### POST `/propose-question`
**Purpose**: Submit user-generated questions for review  
**Authentication**: Bearer token required

**Request Body:**
```json
{
  "question": "string",
  "title": "string",
  "passage": "string",
  "suggested_answer": boolean,
  "tags": ["string"],
  "submitter_id": "string"
}
```

**Response:**
```json
{
  "message": "Question submitted for review",
  "submission_id": "sub_123456789"
}
```

### 🐛 Debug Endpoints

#### GET `/auth-ping`
**Purpose**: Validate JWT token and return payload  
**Authentication**: Bearer token required

**Response:**
```json
{
  "valid": true,
  "payload": {
    "session_id": "demo-session-123",
    "exp": 1234567890
  },
  "message": "Token is valid"
}
```

## Data Models

### Question Object
```json
{
  "id": "string",           // Unique question identifier
  "question": "string",     // The question text
  "title": "string",        // Question title/summary
  "passage": "string",      // Context passage
  "answer": boolean,        // Canonical true/false answer
  "tags": ["string"]        // Category tags
}
```

### Answer Input Object
```json
{
  "user_id": "string",      // User session identifier
  "question_id": "string",  // Question being answered
  "answer": boolean,        // User's true/false answer
  "timestamp": number,      // Unix timestamp of answer
  "response_time_ms": number // Time taken to answer (optional)
}
```

### Question Submission Object
```json
{
  "question": "string",        // The question text
  "title": "string",           // Question title
  "passage": "string",         // Context passage
  "suggested_answer": boolean, // Suggested true/false answer
  "tags": ["string"],          // Suggested category tags
  "submitter_id": "string"     // User who submitted
}
```

## Error Responses

### Authentication Errors
```json
{
  "error": "Unauthorized",
  "message": "Invalid or missing JWT token"
}
```
**Status Code**: 401

### Validation Errors
```json
{
  "error": "Bad Request",
  "message": "Invalid request parameters",
  "details": {
    "field": "count",
    "issue": "Must be between 1 and 10"
  }
}
```
**Status Code**: 400

### Server Errors
```json
{
  "error": "Internal Server Error",
  "message": "An unexpected error occurred"
}
```
**Status Code**: 500

## CORS Configuration

- **Allowed Origin**: `https://truthbyte.voidtalker.com`
- **Allowed Methods**: GET, POST, OPTIONS
- **Allowed Headers**: Content-Type, Authorization, X-Amz-Date, X-Api-Key, X-Amz-Security-Token

## Rate Limiting

Currently no rate limiting is implemented, but requests are subject to AWS Lambda concurrent execution limits.

## JWT Token Details

- **Algorithm**: HS256 (HMAC with SHA-256)
- **Expiration**: 12 hours from issue time
- **Payload**: Contains `session_id` and `exp` (expiration timestamp)

## Example API Workflows

### Complete Game Session
```bash
# 1. Get authentication token
TOKEN=$(curl -s https://api.truthbyte.voidtalker.com/v1/session | jq -r .token)

# 2. Fetch questions
curl -H "Authorization: Bearer $TOKEN" \
     "https://api.truthbyte.voidtalker.com/v1/fetch-questions?count=5"

# 3. Submit answers
curl -X POST \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"answers":[{"user_id":"demo-user","question_id":"q001","answer":true,"timestamp":1710000000}]}' \
     https://api.truthbyte.voidtalker.com/v1/submit-answers
```

### Question Submission Workflow
```bash
# 1. Authenticate
TOKEN=$(curl -s https://api.truthbyte.voidtalker.com/v1/session | jq -r .token)

# 2. Submit question
curl -X POST \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "question": "Is water wet?",
       "title": "Water wetness",
       "passage": "Water is a liquid that...",
       "suggested_answer": true,
       "tags": ["science", "general"],
       "submitter_id": "user123"
     }' \
     https://api.truthbyte.voidtalker.com/v1/propose-question
```

---

**Last Updated**: Current as of latest backend deployment  
**Version**: 1.0.0 