import json
import boto3
import uuid
import os
import sys
import time
import re
from typing import Dict, Any, List

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token, extract_user_id
from user_utils import get_or_create_user

# --- Security Constants ---
MAX_QUESTION_LENGTH = 200
MAX_TAG_LENGTH = 50
MAX_TAGS_TOTAL_LENGTH = 150
MIN_QUESTION_LENGTH = 10
MAX_TITLE_LENGTH = 100
MAX_PASSAGE_LENGTH = 500
MAX_TAGS_COUNT = 5

# --- Input Validation Functions ---

def is_safe_text(text: str) -> bool:
    """Check if text contains only safe characters (printable ASCII)"""
    if not text:
        return False
    
    # Allow only printable ASCII characters
    for char in text:
        if ord(char) < 32 or ord(char) > 126:
            # Allow some common whitespace
            if char not in ['\n', '\r', '\t']:
                return False
    return True

def contains_suspicious_patterns(text: str) -> bool:
    """Check for common injection patterns and suspicious content"""
    if not text:
        return False
    
    # Convert to lowercase for case-insensitive checking
    text_lower = text.lower()
    
    # Suspicious patterns that could indicate injection attempts
    suspicious_patterns = [
        '<script', 'javascript:', 'data:', 'vbscript:', 'onload=', 'onerror=',
        'onclick=', 'eval(', 'document.', 'window.', '\\x', '\\u',
        '%3c', '%3e', '&#', 'union select', 'drop table', 'insert into',
        'delete from', 'update set', '<iframe', '<object', '<embed',
        'expression(', 'url(', '@import', 'behavior:', '-moz-binding'
    ]
    
    for pattern in suspicious_patterns:
        if pattern in text_lower:
            return True
    
    return False

def has_excessive_repeated_chars(text: str) -> bool:
    """Check for spam-like repeated characters"""
    if len(text) < 4:
        return False
    
    consecutive_count = 1
    prev_char = text[0]
    
    for char in text[1:]:
        if char == prev_char:
            consecutive_count += 1
            if consecutive_count > 4:  # More than 4 consecutive same chars
                return True
        else:
            consecutive_count = 1
            prev_char = char
    
    return False

def sanitize_text(text: str, max_length: int) -> str:
    """Sanitize text by removing dangerous characters and limiting length"""
    if not text:
        return ""
    
    # Remove control characters except common whitespace
    sanitized = ""
    consecutive_spaces = 0
    
    for char in text:
        if ord(char) >= 32 and ord(char) <= 126:
            # Limit consecutive spaces
            if char == ' ':
                consecutive_spaces += 1
                if consecutive_spaces <= 2:  # Allow max 2 consecutive spaces
                    sanitized += char
            else:
                consecutive_spaces = 0
                sanitized += char
        elif char in ['\n', '\r', '\t']:
            # Convert to single space
            if consecutive_spaces < 2:
                sanitized += ' '
                consecutive_spaces += 1
    
    # Trim and limit length
    sanitized = sanitized.strip()[:max_length]
    return sanitized

def validate_question_input(question: str, categories: List[str], title: str = "", passage: str = "") -> Dict[str, Any]:
    """Comprehensive validation of question input"""
    errors = []
    
    # Question validation
    if not question or len(question.strip()) < MIN_QUESTION_LENGTH:
        errors.append(f"Question must be at least {MIN_QUESTION_LENGTH} characters long")
    elif len(question) > MAX_QUESTION_LENGTH:
        errors.append(f"Question must be less than {MAX_QUESTION_LENGTH} characters")
    elif not is_safe_text(question):
        errors.append("Question contains invalid characters")
    elif contains_suspicious_patterns(question):
        errors.append("Question contains suspicious content")
    elif has_excessive_repeated_chars(question):
        errors.append("Question contains excessive repeated characters")
    else:
        # Check if question ends with proper punctuation
        trimmed_question = question.strip()
        if trimmed_question and trimmed_question[-1] not in ['?', '.', '!']:
            errors.append("Question should end with proper punctuation")
        
        # Check for meaningful content (at least 5 letters)
        letter_count = sum(1 for c in trimmed_question if c.isalpha())
        if letter_count < 5:
            errors.append("Question must contain meaningful text")
    
    # Categories validation
    if not categories or len(categories) == 0:
        errors.append("At least one category is required")
    elif len(categories) > MAX_TAGS_COUNT:
        errors.append(f"Maximum {MAX_TAGS_COUNT} categories allowed")
    else:
        total_categories_length = sum(len(cat) for cat in categories)
        if total_categories_length > MAX_TAGS_TOTAL_LENGTH:
            errors.append(f"Total categories length must be less than {MAX_TAGS_TOTAL_LENGTH} characters")
        
        for category in categories:
            if not category or len(category.strip()) == 0:
                errors.append("Empty categories are not allowed")
            elif len(category) > MAX_TAG_LENGTH:
                errors.append(f"Each category must be less than {MAX_TAG_LENGTH} characters")
            elif not re.match(r'^[a-zA-Z0-9\s\-_]+$', category):
                errors.append("Categories can only contain letters, numbers, spaces, hyphens, and underscores")
            elif contains_suspicious_patterns(category):
                errors.append("Category contains suspicious content")
    
    # Title validation (optional)
    if title and len(title) > MAX_TITLE_LENGTH:
        errors.append(f"Title must be less than {MAX_TITLE_LENGTH} characters")
    elif title and (not is_safe_text(title) or contains_suspicious_patterns(title)):
        errors.append("Title contains invalid or suspicious content")
    
    # Passage validation (optional)
    if passage and len(passage) > MAX_PASSAGE_LENGTH:
        errors.append(f"Passage must be less than {MAX_PASSAGE_LENGTH} characters")
    elif passage and (not is_safe_text(passage) or contains_suspicious_patterns(passage)):
        errors.append("Passage contains invalid or suspicious content")
    
    return {
        'valid': len(errors) == 0,
        'errors': errors
    }

def check_rate_limit(user_id: str, current_time: int) -> Dict[str, Any]:
    """Check if user has exceeded rate limits for question submission"""
    try:
        # Get rate limiting table
        rate_limit_table_name = os.environ.get('RATE_LIMIT_TABLE_NAME', 'truthbyte-rate-limits')
        dynamodb = boto3.resource('dynamodb')
        rate_limit_table = dynamodb.Table(rate_limit_table_name)
        
        # Rate limits: 3 questions per hour, 10 per day
        hour_limit = 3
        day_limit = 10
        hour_window = 3600  # 1 hour in seconds
        day_window = 86400  # 24 hours in seconds
        
        # Check hourly limit
        hour_key = f"{user_id}:hour:{current_time // hour_window}"
        day_key = f"{user_id}:day:{current_time // day_window}"
        
        # Get current counts
        try:
            hour_response = rate_limit_table.get_item(Key={'id': hour_key})
            hour_count = hour_response.get('Item', {}).get('count', 0)
        except:
            hour_count = 0
            
        try:
            day_response = rate_limit_table.get_item(Key={'id': day_key})
            day_count = day_response.get('Item', {}).get('count', 0)
        except:
            day_count = 0
        
        # Check limits
        if hour_count >= hour_limit:
            return {
                'allowed': False,
                'retry_after': hour_window - (current_time % hour_window)
            }
        
        if day_count >= day_limit:
            return {
                'allowed': False,
                'retry_after': day_window - (current_time % day_window)
            }
        
        # Update counters
        try:
            # Update hourly counter
            rate_limit_table.put_item(
                Item={
                    'id': hour_key,
                    'count': hour_count + 1,
                    'expires_at': current_time + hour_window + 3600  # TTL with buffer
                }
            )
            
            # Update daily counter
            rate_limit_table.put_item(
                Item={
                    'id': day_key,
                    'count': day_count + 1,
                    'expires_at': current_time + day_window + 3600  # TTL with buffer
                }
            )
        except:
            # If rate limit table doesn't exist or has issues, allow the request
            # This ensures the main functionality isn't broken by rate limiting
            pass
        
        return {'allowed': True}
        
    except Exception:
        # If rate limiting fails, allow the request to proceed
        # Better to have a working system without rate limiting than a broken one
        return {'allowed': True}

def lambda_handler(event, context):
    """
    AWS Lambda handler for proposing new questions.
    
    The function expects an event from API Gateway with a JSON body containing
    the question data. The body should include:
    - question: The question text
    - answer: Boolean true/false answer
    - title: Optional context title
    - passage: Optional background passage
    - tags: List of category tags
    
    Requires JWT authentication via Authorization: Bearer <token> header.
    
    API Gateway Integration:
    - Request body is passed in event['body'] as a JSON string
    - Response must include statusCode and body
    - CORS headers are required for browser access
    
    Returns:
        API Gateway response with:
        - statusCode: 200 for success, 400 for invalid input, 401 for auth errors, 500 for errors
        - body: JSON string containing success status and question data or error
    """
    try:
        # JWT Authentication Check
        headers = event.get('headers', {})
        auth_header = headers.get('Authorization', '') or headers.get('authorization', '')
        
        if not auth_header.startswith('Bearer '):
            return {
                'statusCode': 401,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
                },
                'body': json.dumps({'error': 'Missing or invalid token'})
            }
        
        try:
            token = auth_header[len("Bearer "):]
            payload = verify_token(token)
            session_id = payload["session_id"]
        except Exception:
            return {
                'statusCode': 401,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                'body': json.dumps({'error': 'Invalid token'})
            }
        
        # Validate and get user ID - needed for tracking question authorship
        try:
            user_id = extract_user_id(headers)
            # Ensure user exists in database (creates if not)
            user = get_or_create_user(user_id)
        except ValueError as e:
            return {
                'statusCode': 400,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                'body': json.dumps({'error': str(e)})
            }
        
        # SECURITY: Rate limiting check
        current_time = int(time.time())
        rate_limit_result = check_rate_limit(user_id, current_time)
        if not rate_limit_result['allowed']:
            return {
                'statusCode': 429,  # Too Many Requests
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID",
                    "Retry-After": str(rate_limit_result['retry_after'])
                },
                'body': json.dumps({
                    'success': False,
                    'error': 'Rate limit exceeded. Please wait before submitting another question.',
                    'retry_after': rate_limit_result['retry_after']
                })
            }
        
        # Parse the request body from API Gateway event
        # API Gateway wraps the body in a "body" field as a string
        try:
            body = json.loads(event["body"]) if "body" in event else event
        except (json.JSONDecodeError, TypeError):
            return {
                "statusCode": 400,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
                },
                "body": json.dumps({
                    "success": False,
                    "error": "Invalid JSON in request body"
                })
            }
        
        # Get DynamoDB table resource
        table_name = os.environ.get('SUBMITTED_QUESTIONS_TABLE_NAME', 'truthbyte-submitted-questions')
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table_name)
        
        # Validate required fields for TruthByte format
        required_fields = {"question", "answer"}
        categories_field = body.get("categories") or body.get("tags")  # Support both for backwards compatibility
        
        if not all(field in body for field in required_fields) or not categories_field:
            return {
                "statusCode": 400,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
                },
                "body": json.dumps({
                    "success": False,
                    "error": "Missing required fields: question, answer (boolean), categories"
                })
            }
        
        # Validate answer is boolean
        if not isinstance(body["answer"], bool):
            return {
                "statusCode": 400,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
                },
                "body": json.dumps({
                    "success": False,
                    "error": "Answer must be a boolean value (true/false)"
                })
            }
        
        # SECURITY: Comprehensive input validation
        question = str(body["question"]).strip()
        categories = categories_field if isinstance(categories_field, list) else [str(categories_field)]
        title = str(body.get("title", "")).strip()
        passage = str(body.get("passage", "")).strip()
        
        validation_result = validate_question_input(question, categories, title, passage)
        if not validation_result['valid']:
            return {
                "statusCode": 400,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
                },
                "body": json.dumps({
                    "success": False,
                    "error": "Input validation failed",
                    "details": validation_result['errors']
                })
            }
        
        # Sanitize all text inputs
        question = sanitize_text(question, MAX_QUESTION_LENGTH)
        title = sanitize_text(title, MAX_TITLE_LENGTH)
        passage = sanitize_text(passage, MAX_PASSAGE_LENGTH)
        categories = [sanitize_text(cat.strip(), MAX_TAG_LENGTH) for cat in categories if cat.strip()]
        
        # Get difficulty from body (optional, default to 3 - medium)
        difficulty = body.get("difficulty", 3)
        try:
            difficulty = int(difficulty)
            if difficulty < 1 or difficulty > 5:
                difficulty = 3
        except (ValueError, TypeError):
            difficulty = 3
        
        # Generate a unique question ID
        question_id = f"q_{uuid.uuid4().hex[:8]}"
        
        # Prepare the item for DynamoDB (TruthByte format)
        item = {
            "id": question_id,
            "question": question,
            "title": title,  # Sanitized context title
            "passage": passage,  # Sanitized background passage
            "answer": body["answer"],  # Boolean answer
            "categories": categories,  # Sanitized categories
            "difficulty": difficulty,  # Difficulty rating 1-5
            "status": "pending",  # Questions start as pending until approved
            "submitted_at": int(time.time()),  # Timestamp for review queue
            "author": user_id,  # User ID of the question author
            "accepted": False  # Track approval status for rewards
        }
        
        # Use put_item with condition expression to prevent duplicates
        # This is a safety check, though unlikely with UUID
        table.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(id)"  # Ensure ID doesn't exist
        )
        
        # Return success response
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
            },
            "body": json.dumps({
                "success": True,
                "data": item
            })
        }
    except Exception as e:
        # Return error response
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
            },
            "body": json.dumps({
                "success": False,
                "error": str(e)
            })
        } 