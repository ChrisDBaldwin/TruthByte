# TruthByte Agentic Coding Specifications

> **Purpose**: This document provides comprehensive specifications for AI agents to understand and effectively contribute to the TruthByte codebase.

## Project Overview

**TruthByte** is a WASM-based game that crowdsources human truth judgments to build better LLM evaluation datasets. Users play "True or False?" rounds where every answer contributes to training data.

### Key Architecture Components

```
Frontend (Zig → WASM) ←→ API Gateway ←→ Lambda Functions ←→ DynamoDB Tables
     ↕                      ↕                    ↕              ↕
Mobile/Desktop UI      CloudFormation      Python Backend    Data Storage
```

## Directory Structure & Critical Files

### Backend (`/backend/`)
- **`lambda/`** - AWS Lambda functions (Python 3.13.5+)
  - `fetch_questions.py` - GET /v1/fetch-questions endpoint
  - `submit_answers.py` - POST /v1/submit-answers endpoint  
  - `propose_question.py` - POST /v1/propose-question endpoint
  - `get_token.py` - GET /v1/session endpoint (JWT tokens)
  - `auth_ping.py` - GET /v1/auth-ping endpoint
- **`shared/`** - Common utilities
  - `models.py` - Pydantic data models
  - `db.py` - DynamoDB connection helper
  - `auth_utils.py` - JWT authentication utilities

### Frontend (`/frontend/`)
- **`src/`** - Zig source code
  - `main_release.zig` - WASM production entry point
  - `main_hot.zig` - Native development entry point
  - `game.zig` - Core game logic and UI
- **`build.zig`** - Zig build configuration
- **`shell.html`** - WASM container HTML

### Infrastructure (`/deploy/infra/`)
- **`dynamodb.yaml`** - DynamoDB table definitions
- **`api.yaml`** - API Gateway configuration
- **`lambdas.yaml`** - Lambda function definitions
- **`cloudfront.yaml`** - CDN configuration
- **`frontend-s3.yaml`** / **`backend-s3.yaml`** - S3 bucket configs

## Data Models & Database Schema

### DynamoDB Tables

#### 1. Questions Table (`{env}-truthbyte-questions`)
```
Partition Key: id (String)
Attributes:
- id: String (unique identifier)
- question: String (the question text)
- answer: Boolean (canonical true/false answer)
- title: String (question title/summary)
- passage: String (context passage)
- tags: List<String> (categorization tags)
```

#### 2. Question-Tags Table (`{env}-truthbyte-question-tags`)
```
Partition Key: tag (String)
Sort Key: question_id (String)
Purpose: Tag-based indexing for O(1) question lookups by category
```

#### 3. Answers Table (`{env}-truthbyte-answers`)
```
Partition Key: user_id (String)
Sort Key: question_id (String)
Attributes:
- answer: Boolean
- timestamp: Number
- response_time_ms: Number (optional)
```

#### 4. Sessions Table (`{env}-truthbyte-sessions`)
```
Partition Key: session_id (String)
GSI: ip-hash-index (ip_hash as partition key)
Attributes:
- ip_hash: String
- created_at: Number (timestamp)
- trust_score: Number (calculated)
```

#### 5. Submitted Questions Table (`{env}-truthbyte-submitted-questions`)
```
Partition Key: id (String)
Attributes:
- question: String
- suggested_answer: Boolean
- submitter_id: String
- status: String (pending/approved/rejected)
- created_at: Number
```

## API Endpoints

### Base URL
- **Production**: `https://api.truthbyte.voidtalker.com/v1`
- **Development**: Determined by CloudFormation stack

### Endpoints

#### GET `/fetch-questions?tag={tag}&count={count}`
**Purpose**: Retrieve randomized questions by tag
**Parameters**:
- `tag` (optional): Category filter (default: "general")
- `count` (optional): Number of questions (default: 5, max: 10)
**Response**: Array of question objects with id, question, title, passage, tags

#### POST `/submit-answers`
**Purpose**: Submit user answers and calculate trust score
**Body**: Array of `AnswerInput` objects
```json
{
  "user_id": "string",
  "question_id": "string", 
  "answer": boolean,
  "timestamp": number,
  "response_time_ms": number
}
```

#### POST `/propose-question`
**Purpose**: Submit user-generated questions for review
**Body**: Question proposal object

#### GET `/session`
**Purpose**: Get JWT session token
**Response**: JWT token for user session

#### GET `/auth-ping` 
**Purpose**: Verify JWT token validity
**Headers**: `Authorization: Bearer {token}`

## Development Patterns & Conventions

### Backend Development
1. **Lambda Function Structure**:
   ```python
   def lambda_handler(event, context):
       # CORS headers for all responses
       headers = {
           'Access-Control-Allow-Origin': 'https://truthbyte.voidtalker.com',
           'Access-Control-Allow-Headers': 'Content-Type',
           'Content-Type': 'application/json'
       }
       
       try:
           # Main logic here
           return {
               'statusCode': 200,
               'headers': headers,
               'body': json.dumps(result)
           }
       except Exception as e:
           return {
               'statusCode': 500,
               'headers': headers,
               'body': json.dumps({'error': str(e)})
           }
   ```

2. **DynamoDB Operations**: Use `backend/shared/db.py` helper
3. **Data Validation**: Use Pydantic models from `backend/shared/models.py`
4. **Environment Variables**: Tables prefixed with `{ENVIRONMENT}-`

### Frontend Development
1. **Build Targets**:
   - Native: `zig build run` (development with hot reload)
   - WASM: `zig build -Dtarget=wasm32-emscripten run` (production)

2. **Input Handling**: Unified mouse/touch/keyboard system in `game.zig`

3. **Mobile Optimization**: 
   - Touch coordinate mapping via JavaScript bridge
   - Viewport handling for mobile browsers
   - iOS Safari specific optimizations

### Infrastructure as Code
1. **CloudFormation Stacks**: All infrastructure defined in YAML
2. **Environment Separation**: `dev` and `prod` parameter-driven
3. **Resource Naming**: `{Environment}-truthbyte-{resource}`
4. **Deployment**: Automated via PowerShell/Bash scripts in `/deploy/scripts/`

## Key Development Commands

### Frontend
```bash
# Development (native)
cd frontend && zig build run

# Production build (WASM)  
cd frontend && zig build -Dtarget=wasm32-emscripten run

# Dependencies check
zig version  # Should be 0.14.0+
```

### Backend
```bash
# Install dependencies
pip install -r backend/requirements.txt

# Local testing (requires AWS credentials)
python backend/lambda/fetch_questions.py
```

### Deployment
```bash
# Full deployment
./deploy/scripts/deploy.ps1  # Windows
./deploy/scripts/deploy.sh   # Unix

# Backend only
./deploy/scripts/deploy-backend.ps1

# Frontend only  
./deploy/scripts/deploy-frontend.ps1
```

## Performance Considerations

### Backend Optimization
1. **Tag-Based Querying**: Uses dual-table design to avoid table scans
2. **Batch Operations**: DynamoDB batch reads for multiple questions
3. **Random Sampling**: Client-side randomization to reduce server load
4. **Pay-per-request**: DynamoDB billing optimized for sporadic usage

### Frontend Optimization
1. **WASM Compilation**: Optimized Zig → WASM pipeline
2. **Mobile Performance**: 60fps target with efficient rendering
3. **Network Efficiency**: Minimal API calls, batch question fetching

## Security Model

### Authentication
- **JWT Tokens**: Session-based authentication via `/session` endpoint
- **IP Tracking**: Hashed IP addresses for abuse prevention
- **Trust Scoring**: User reliability calculated from answer patterns

### CORS Configuration
- **Origin**: `https://truthbyte.voidtalker.com`
- **Methods**: GET, POST, OPTIONS
- **Headers**: Content-Type, Authorization

## Testing & Validation

### Backend Testing
1. **Local Lambda Testing**: Direct Python execution
2. **DynamoDB Local**: Use local DynamoDB for development
3. **API Testing**: Use curl/Postman against deployed endpoints

### Frontend Testing
1. **Native Testing**: Fast iteration with `main_hot.zig`
2. **WASM Testing**: Browser testing with `main_release.zig`
3. **Mobile Testing**: Device testing on iOS/Android

## Common Debugging Patterns

### Backend Issues
1. **CloudFormation**: Check stack status in AWS Console
2. **Lambda Logs**: CloudWatch logs for function execution
3. **DynamoDB**: Check table structure and data via AWS Console
4. **CORS**: Verify headers in browser dev tools

### Frontend Issues
1. **WASM Loading**: Check browser console for load errors
2. **Input Issues**: Mobile touch coordinate problems
3. **Build Issues**: Verify EMSDK environment variable

## Code Style & Standards

### Python (Backend)
- **Type Hints**: Use for all function parameters and returns
- **Pydantic Models**: For all data validation
- **Error Handling**: Consistent JSON error responses
- **Logging**: Use print() for Lambda (goes to CloudWatch)

### Zig (Frontend)  
- **Memory Management**: Use provided allocator, clean up resources
- **Error Handling**: Use Zig's error union types
- **Cross-Platform**: Support both native and WASM targets
- **Performance**: Prefer stack allocation where possible

## Environment Variables & Configuration

### Required Environment Variables
- **EMSDK**: Path to Emscripten SDK (frontend builds)
- **AWS Credentials**: For deployment and backend testing

### Runtime Configuration
- **Table Names**: Dynamically constructed with environment prefix
- **API Endpoints**: CloudFormation outputs determine URLs
- **CORS Origins**: Hardcoded to production domain

## Troubleshooting Guide

### Common Issues for AI Agents

1. **"Table not found" errors**: Check environment prefix in table names
2. **CORS failures**: Verify origin matches exactly in API configuration
3. **WASM build failures**: Ensure EMSDK environment variable is set
4. **Lambda timeout**: Check CloudWatch logs for performance bottlenecks
5. **DynamoDB access denied**: Verify IAM roles in `lambdas.yaml`

### File Modification Guidelines

1. **Lambda Functions**: Always maintain CORS headers and error handling
2. **Infrastructure YAML**: Validate syntax and parameter dependencies
3. **Frontend Zig**: Test both native and WASM builds after changes
4. **Data Models**: Update both Pydantic models and DynamoDB schemas

---

**Last Updated**: Current as of codebase state  
**Target Audience**: AI coding assistants and automated development tools 