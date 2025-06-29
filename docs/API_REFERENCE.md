# TruthByte API Reference

Complete reference for all TruthByte API endpoints, authentication, and data models.

## Base URL

- **Production**: `https://api.truthbyte.voidtalker.com/v1`
- **Development**: Determined by CloudFormation stack deployment
- **Local**: `http://localhost:3000/v1`

## Authentication

All protected endpoints require JWT authentication via Bearer token and user identification via X-User-ID header.

### Getting a Token

```http
GET /session
```

**Response:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "Bearer",
  "expires_in": 43200
}
```

### Token Refresh

```http
POST /refresh
```

**Request Body:**
```json
{
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

**Response:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "Bearer",
  "expires_in": 43200
}
```

### Error Responses

All endpoints may return these error responses:

**401 Unauthorized:**
```json
{
  "error": "Token has expired",
  "error_code": "token_expired"
}
```

**400 Bad Request:**
```json
{
  "error": "Missing X-User-ID header",
  "error_code": "missing_header"
}
```

**500 Internal Server Error:**
```json
{
  "error": "Internal server error",
  "error_code": "internal_error",
  "request_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

### Debug Information

All error responses may include additional debug information in development environments:

```json
{
  "error": "No questions found for category: science",
  "error_code": "not_found",
  "debug_info": {
    "scan_limit": 100,
    "filter_applied": true,
    "total_scanned_items": 50,
    "categories_table_available": true,
    "requested_category": "science",
    "category_is_general": false,
    "python_filter_applied": true
  }
}
```

## Rate Limiting

All endpoints are rate limited:

- **Authentication endpoints**: 100 requests per hour per IP
- **Protected endpoints**: 1000 requests per hour per user
- **Question submission**: 3 questions per hour, 10 per day per user

Rate limit headers are included in all responses:
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1616173264
```

## Endpoints

### 🔓 Public Endpoints

#### GET `/session`
**Purpose**: Generate JWT session token  
**Authentication**: None required  
**Rate Limit**: 100/hour/IP

**Response:**
```json
{
  "access_token": "string",
  "refresh_token": "string",
  "token_type": "Bearer",
  "expires_in": 43200
}
```

### 🔒 Protected Endpoints

All endpoints below require JWT authentication and X-User-ID header.

#### GET `/fetch-questions`
**Purpose**: Retrieve randomized questions by category and difficulty  
**Authentication**: Bearer token required  
**Rate Limit**: 1000/hour/user

**Query Parameters:**
- `category` (optional): Category filter (default: "general")
- `difficulty` (optional): Difficulty filter 1-5 (default: all difficulties)
- `num_questions` (optional): Number of questions (default: 7, max: 20)

**Example Request:**
```http
GET /fetch-questions?category=science&difficulty=3&num_questions=7
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
X-User-ID: 12345678-1234-4xxx-yxxx-xxxxxxxxxxxx
```

**Success Response:**
```json
{
  "questions": [
    {
      "id": "q001",
      "question": "Does ethanol take more energy to make than it produces?",
      "title": "Ethanol fuel energy balance",
      "passage": "All biomass goes through at least some of these steps...",
      "answer": false,
      "categories": ["science", "energy"],
      "difficulty": 3
    }
  ],
  "count": 1,
  "category": "science",
  "difficulty": 3,
  "requested_count": 7
}
```

**Error Response (404):**
```json
{
  "error": "No questions found for category: science",
  "error_code": "not_found",
  "debug_info": {
    "scan_limit": 100,
    "filter_applied": true,
    "total_scanned_items": 50,
    "categories_table_available": true,
    "requested_category": "science",
    "category_is_general": false,
    "python_filter_applied": true
  }
}
```

#### GET `/fetch-daily-questions`
**Purpose**: Retrieve deterministic daily questions for the daily mode challenge
**Authentication**: Bearer token required

**Features:**
- **Deterministic Selection**: Same 10 questions for all users on a given date
- **Date-based Seeding**: Uses cryptographic hash of date for consistent randomization
- **Progress Tracking**: Returns user's daily progress and streak information
- **Difficulty Filtering**: Excludes hardest questions (difficulty 5) from daily challenges

**Example Request:**
```http
GET /fetch-daily-questions
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
X-User-ID: 12345678-1234-4xxx-yxxx-xxxxxxxxxxxx
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
      "categories": ["science", "energy"],
      "difficulty": 3
    }
  ],
  "date": "2024-01-15",
  "daily_progress": {
    "completed": false,
    "score": 0,
    "answers": [],
    "completed_at": null
  },
  "streak_info": {
    "current_streak": 5,
    "best_streak": 12,
    "streak_eligible": true
  },
  "total_questions": 10
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

#### GET `/categories`
**Purpose**: Retrieve available categories with question counts  
**Authentication**: Bearer token required

**Response:**
```json
{
  "categories": [
    {
      "name": "science",
      "count": 75
    },
    {
      "name": "history", 
      "count": 50
    }
  ],
  "total_categories": 8,
  "total_questions": 500
}
```

#### POST `/propose-question`
**Purpose**: Submit user-generated questions for review  
**Authentication**: Bearer token required

**🔒 Security Features:**
- **Input Validation**: Comprehensive validation of all fields
- **Content Sanitization**: Removes dangerous characters and patterns
- **Rate Limiting**: 3 questions/hour, 10/day per user
- **Injection Prevention**: Blocks XSS, code injection, binary content
- **Length Limits**: Questions 10-200 chars, categories 1-50 chars each

**Request Body:**
```json
{
  "question": "string",        // 10-200 characters, must end with punctuation
  "title": "string",           // Optional, max 100 characters
  "passage": "string",         // Optional, max 500 characters
  "answer": boolean,           // Required true/false answer
  "categories": ["string"],    // 1-5 categories, each 1-50 chars
  "difficulty": 3              // Optional, 1-5 difficulty rating
}
```

**Validation Rules:**
- **Question**: 10-200 characters, must end with punctuation, minimum 5 letters
- **Categories**: 1-5 categories, each 1-50 characters, letters/numbers/spaces/hyphens/underscores only
- **Title**: Optional, max 100 characters
- **Passage**: Optional, max 500 characters
- **Answer**: Required boolean

**Success Response:**
```json
{
  "success": true,
  "data": {
    "id": "q_a1b2c3d4",
    "question": "Is renewable energy more cost-effective than fossil fuels?",
    "answer": true,
    "title": "Renewable Energy Economics", 
    "passage": "Recent studies show renewable energy costs...",
    "categories": ["science", "economics"],
    "difficulty": 3,
    "status": "pending",
    "submitted_at": 1710000000,
    "author": "user123",
    "accepted": false
  }
}
```

**Error Responses:**
```json
// Rate limit exceeded (429)
{
  "success": false,
  "error": "Rate limit exceeded. Please wait before submitting another question.",
  "retry_after": 3600
}

// Validation failed (400)
{
  "success": false,
  "error": "Input validation failed",
  "details": [
    "Question must be at least 10 characters long",
    "Categories can only contain letters, numbers, spaces, hyphens, and underscores"
  ]
}

// Suspicious content detected (400)
{
  "success": false,
  "error": "Input validation failed",
  "details": ["Question contains suspicious content"]
}
```

#### POST `/submit-daily-answers`
**Purpose**: Submit answers for the daily mode challenge
**Authentication**: Bearer token required

**Features:**
- **Score Calculation**: Calculates percentage score and letter rank (S, A, B, C, D)
- **Streak Management**: Updates user's daily streak based on performance (≥70% required)
- **Progress Tracking**: Stores completion status and prevents duplicate submissions
- **Rank System**: S (100%), A (80-99%), B (70-79%), C (60-69%), D (<60%)

**Request Body:**
```json
{
  "answers": [
    {
      "question_id": "q001",
      "answer": true,
      "timestamp": 1705324800
    },
    {
      "question_id": "q002", 
      "answer": false,
      "timestamp": 1705324820
    }
  ],
  "date": "2024-01-15"
}
```

**Response:**
```json
{
  "success": true,
  "score": {
    "correct_count": 8,
    "total_questions": 10,
    "score_percentage": 80.0,
    "rank": "A",
    "streak_eligible": true
  },
  "streak_info": {
    "current_streak": 6,
    "best_streak": 12,
    "streak_continued": true
  },
  "date": "2024-01-15"
}
```

#### GET `/user`

Get user profile and progress information.

**Response:**
```json
{
    "user_id": "uuid-string",
    "trust_score": 42,
    "created_at": "2024-01-15T12:34:56.789Z",
    "last_active": "2024-01-15T12:34:56.789Z",
    "daily_progress": {
        "2024-01-15": {
            "answers": [
                {
                    "question_id": "q001",
                    "answer": true,
                    "is_correct": true,
                    "timestamp": 1234567890
                }
            ],
            "completed_at": "2024-01-15T12:34:56.789Z"
        }
    },
    "current_daily_streak": 5,
    "best_daily_streak": 10
}
```

Note: Statistics like total questions answered, correct answers, and total daily games can be calculated from the answers table and daily progress data.

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
  "categories": ["string"], // Primary category system
  "difficulty": 3,          // Difficulty rating 1-5 (1=easy, 5=hard)
  "tags": ["string"]        // Legacy field, use categories instead
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

**Question Submission Rate Limits:**
- **3 questions per hour** per user
- **10 questions per day** per user
- **HTTP 429** status code when limits exceeded
- **Retry-After** header indicates wait time in seconds

**Other Endpoints:**
- No rate limiting currently implemented
- Subject to AWS Lambda concurrent execution limits

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