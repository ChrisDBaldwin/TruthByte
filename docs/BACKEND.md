# TruthByte Python Lambda Backend

A scalable, tag-based backend system for TruthByte built on AWS Lambda and DynamoDB. Uses an efficient dual-table architecture to avoid expensive table scans.

## Architecture Overview

### **🚀 Tag-Based Query System**
- **No Table Scans**: All queries use efficient tag-based indexing
- **Default Tag Strategy**: Every question has a `general` tag for universal queries
- **Dual-Table Design**: Separate tables for questions and tag mappings
- **Sub-second Response**: Optimized for fast, predictable performance

### Lambda Functions

- `fetch_questions` - Returns randomized batches of questions by tag
- `submit_answers` - Processes user answers and calculates trust scores  
- `propose_question` - **Secure** user question submission with comprehensive validation
- `get_user` - Retrieves user profile and statistics
- `get_token` - Issues JWT authentication tokens
- `auth_ping` - Validates JWT tokens (debug endpoint)
- `fetch_daily_questions` - **NEW** Provides deterministic daily questions for daily mode
- `submit_daily_answers` - **NEW** Processes daily mode submissions with score calculation and streak tracking
- `get_categories` - Retrieves available question categories with counts
- `get_user_submissions` - Retrieves user's submitted questions for review
- `approve_question` - Approves user-submitted questions for inclusion in question pool

### Security Features

**🔒 Input Validation & Sanitization**
- **Multi-layer Security**: Frontend + backend validation
- **Injection Prevention**: XSS, SQL injection, code injection protection
- **Binary Content Blocking**: Prevents image/binary data submission
- **Content Sanitization**: Removes dangerous characters and patterns
- **Rate Limiting**: 3 questions/hour, 10/day per user

**🛡️ Security Architecture**
- **Character Validation**: Only printable ASCII allowed
- **Pattern Detection**: Blocks `<script>`, `javascript:`, `eval()`, etc.
- **Length Limits**: Enforced at multiple levels
- **Spam Detection**: Prevents repeated character abuse
- **Real-time Threat Response**: Immediate content clearing on detection

## Structure

- `lambda/`: Lambda function handlers
  - `fetch_questions.py` - Question retrieval with tag-based filtering
  - `submit_answers.py` - Answer processing and trust score calculation
  - `propose_question.py` - User question submissions
  - `get_user.py` - User profile and statistics retrieval
  - `get_token.py` - JWT token generation for authentication
  - `auth_ping.py` - JWT token validation endpoint
  - `fetch_daily_questions.py` - **NEW** Deterministic daily question selection
  - `submit_daily_answers.py` - **NEW** Daily mode answer processing and streak management
  - `get_categories.py` - Category listing with question counts
  - `get_user_submissions.py` - User-submitted question retrieval
  - `approve_question.py` - Question approval workflow
- `shared/`: Shared code modules
  - `db.py` - DynamoDB client and operations
  - `models.py` - Pydantic data models
  - `auth_utils.py` - JWT authentication utilities
  - `user_utils.py` - User management and statistics

## DynamoDB Tables

### **Questions Table** (`{env}-truthbyte-questions`)
- **Primary Key**: `id` (String) - Unique question identifier
- **Attributes**: `question`, `title`, `passage`, `answer` (boolean), `tags` (list)
- **Purpose**: Stores the full question data and metadata

### **Question Tags Table** (`{env}-truthbyte-question-tags`)  
- **Primary Key**: `tag` (String), `question_id` (String)
- **Purpose**: Efficient tag-to-question mapping for fast queries
- **Benefits**: Enables sub-second tag-based queries without table scans

### **Other Tables**
- **Answers Table**: User responses and trust scoring
- **Sessions Table**: User session tracking with IP hash indexing
- **Submitted Questions Table**: User-proposed questions awaiting review
- **Users Table**: User profiles, daily progress, and streak tracking

### **Daily Mode Features**
- **Deterministic Question Selection**: Same 10 questions for all users on a given date
- **Date-based Seeding**: Uses cryptographic hash to ensure consistent daily questions
- **Progress Tracking**: User daily completion status and historical performance
- **Streak System**: Current and best daily streaks with performance requirements
- **Score Ranking**: Letter grades (S, A, B, C, D) based on percentage correct
- **Difficulty Filtering**: Excludes hardest questions (difficulty 5) from daily challenges

## Setup & Dependencies

### Prerequisites
- Python 3.13.5
- pip (latest version)

### Environment Setup

1. Create and activate a virtual environment:

```sh
# Windows
python -m venv .venv
.venv\Scripts\activate

# macOS/Linux
python3 -m venv .venv
source .venv/bin/activate
```

2. Upgrade pip and install dependencies:

```sh
python -m pip install --upgrade pip
pip install -r requirements.txt
```

### Core Dependencies
- boto3 - AWS SDK for Python
- pydantic - Data validation
- requests - HTTP client library

### Development Dependencies
- black - Code formatting
- flake8 - Linting
- isort - Import sorting
- mypy - Type checking
- pre-commit - Git hooks

### Testing Dependencies
- pytest - Testing framework
- pytest-cov - Code coverage
- pytest-mock - Mocking
- responses - HTTP mocking

To verify the installation:
```sh
python -c "import boto3; import pydantic; print('Setup successful!')"
```

## API Examples

### **Fetch Questions**
```bash
# Get 7 random questions from all categories (uses 'general' tag)
GET /questions?num_questions=7

# Get 5 random science questions
GET /questions?tag=science&num_questions=5

# Get 3 random business questions
GET /questions?tag=business&num_questions=3
```

**Response Format:**
```json
{
  "questions": [
    {
      "id": "q001",
      "question": "does ethanol take more energy make that produces",
      "title": "Ethanol fuel",
      "passage": "All biomass goes through...",
      "answer": false,
      "tags": ["geography", "science", "general"]
    }
  ],
  "count": 1,
  "tag": "science",
  "requested_count": 7
}
```

### **Submit Answers**
```json
{
  "answers": [
    {
      "user_id": "u001",
      "question_id": "q001",
      "answer": true,
      "timestamp": 1710000000
    },
    {
      "user_id": "u001",
      "question_id": "q002",
      "answer": false,
      "timestamp": 1711234567
    }
  ]
}
```

## Performance Characteristics

- **Query Latency**: Sub-second response times for all tag queries
- **Scalability**: Performance doesn't degrade with dataset size
- **Cost Efficiency**: Predictable, low-cost queries (no expensive scans)
- **Throughput**: Supports high concurrent request volumes