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
- `propose_question` - Handles user-submitted questions

## Structure

- `submit_answers.py`, `fetch_questions.py`, `propose_question.py`: Lambda entrypoints (handlers)
- `logic/`: Business logic for each Lambda
- `shared/`: Shared code (e.g., DynamoDB client, data models)

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