# TruthByte Development Guide

This guide covers development setup, common issues, and best practices for the TruthByte project.

## Development Environment Setup

### Prerequisites

- Python 3.13.5
- Node.js 18+ (for frontend development)
- AWS CLI v2
- Git

### Initial Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/truthbyte.git
cd truthbyte
```

2. Create and activate Python virtual environment:
```bash
# Windows
python -m venv .venv
.venv\Scripts\activate

# macOS/Linux
python3 -m venv .venv
source .venv/bin/activate
```

3. Install dependencies:
```bash
pip install -r backend/requirements.txt
pip install -r backend/requirements-dev.txt  # Development dependencies
```

4. Set up pre-commit hooks:
```bash
pre-commit install
```

### Environment Variables

Create a `.env` file in the project root:

```env
# AWS Configuration
AWS_REGION=us-east-1
AWS_PROFILE=truthbyte-dev

# DynamoDB Tables
QUESTIONS_TABLE_NAME=dev-truthbyte-questions
QUESTION_CATEGORIES_TABLE_NAME=dev-truthbyte-question-categories
USERS_TABLE_NAME=dev-truthbyte-users
SESSIONS_TABLE_NAME=dev-truthbyte-sessions

# Authentication
JWT_SECRET=your-development-secret
TOKEN_EXPIRY_HOURS=12
REFRESH_TOKEN_EXPIRY_DAYS=30

# API Configuration
API_BASE_URL=http://localhost:3000
CORS_ORIGIN=http://localhost:3000
```

## Development Workflow

### Code Style

We follow these style guides:
- Python: PEP 8
- JavaScript: Airbnb Style Guide
- Commit Messages: Conventional Commits

### Running Tests

```bash
# Run all tests
pytest

# Run specific test file
pytest tests/test_auth.py

# Run with coverage
pytest --cov=backend tests/
```

### Local Development

1. Start local DynamoDB:
```bash
docker-compose up -d dynamodb-local
```

2. Run Lambda functions locally:
```bash
# Using AWS SAM
sam local start-api

# Or using serverless-offline
serverless offline
```

3. Run frontend development server:
```bash
cd frontend
npm run dev
```

## Common Issues and Solutions

### DynamoDB Local Issues

1. Table Not Found
```bash
# Create tables locally
aws dynamodb create-table \
  --endpoint-url http://localhost:8000 \
  --table-name dev-truthbyte-questions \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

2. Connection Refused
- Check if DynamoDB container is running
- Verify port mapping in docker-compose.yml

### JWT Token Issues

1. Token Expired
- Check system clock synchronization
- Verify TOKEN_EXPIRY_HOURS setting

2. Invalid Signature
- Ensure JWT_SECRET is set correctly
- Check if token was issued by different environment

### AWS Credentials

1. Missing Credentials
```bash
aws configure --profile truthbyte-dev
```

2. Permission Issues
- Verify IAM role permissions
- Check AWS_PROFILE setting

## Debugging Tips

### Lambda Functions

1. Enable debug logging:
```python
import logging
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
```

2. Test locally with event data:
```bash
sam local invoke FetchQuestions -e events/fetch_questions.json
```

### DynamoDB Queries

1. Monitor DynamoDB operations:
```python
import boto3
boto3.set_stream_logger('botocore', logging.DEBUG)
```

2. Use DynamoDB Local GUI:
- NoSQL Workbench
- dynamodb-admin

## Performance Optimization

### DynamoDB Best Practices

1. Avoid table scans:
- Use GSIs for common query patterns
- Design partition keys for even distribution

2. Batch operations:
- Use BatchGetItem for multiple reads
- Use BatchWriteItem for multiple writes

### Lambda Optimization

1. Cold start reduction:
- Keep deployment package small
- Use Lambda layers for dependencies
- Implement connection pooling

2. Memory configuration:
- Monitor memory usage with CloudWatch
- Adjust memory allocation based on usage

## Security Best Practices

### Authentication

1. Token handling:
- Never store tokens in code
- Use secure storage methods
- Implement token refresh flow

2. Input validation:
- Validate all user input
- Use Pydantic models for validation
- Implement rate limiting

### Data Protection

1. Sensitive data:
- Never log sensitive information
- Use AWS KMS for encryption
- Implement proper access controls

2. API security:
- Use HTTPS only
- Implement CORS properly
- Use API Gateway authorizers

## Deployment

### Development Deployment

1. Deploy backend:
```bash
./deploy/scripts/deploy-backend.sh dev
```

2. Deploy frontend:
```bash
./deploy/scripts/deploy-frontend.sh dev
```

### Production Deployment

Additional steps for production:
1. Run security checks
2. Update documentation
3. Create release tag
4. Deploy with blue-green strategy

## Contributing

1. Create feature branch:
```bash
git checkout -b feature/your-feature-name
```

2. Make changes and test:
```bash
pytest
pre-commit run --all-files
```

3. Submit pull request:
- Follow PR template
- Include tests
- Update documentation 