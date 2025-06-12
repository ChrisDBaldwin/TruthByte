# Python Lambda Backend Scaffold

This directory contains a Python 3.13.5 backend with three AWS Lambda functions:

- `submit_answer`
- `fetch_questions`
- `propose_question`

## Structure

- `submit_answer.py`, `fetch_questions.py`, `propose_question.py`: Lambda entrypoints (handlers)
- `logic/`: Business logic for each Lambda
- `shared/`: Shared code (e.g., DynamoDB client, data models)

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

## Example: submit_answer

The `submit_answer` Lambda expects a JSON input like:

```json
{
  "user_id": "u001",
  "question_id": "q001",
  "answer": true,
  "timestamp": 1710000000
}
```

To test locally:

```sh
python -c "import submit_answer; print(submit_answer.lambda_handler({'user_id': 'u001', 'question_id': 'q001', 'answer': true, 'timestamp': 1710000000}, None))"
```

## Notes

- Only `submit_answer` is fully implemented as a working example.
- DynamoDB table name is hardcoded as `answers`.
- Other Lambdas are stubbed for future implementation. 