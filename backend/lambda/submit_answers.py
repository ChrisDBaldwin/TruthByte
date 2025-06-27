import json
import boto3
import os
import sys
from typing import List, Dict, Any

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token, extract_user_id
from user_utils import get_or_create_user, update_user_stats

def validate_answer(answer: Dict[str, Any]) -> bool:
    """Validate a single answer dictionary."""
    required_fields = {"user_id", "question_id", "answer", "timestamp"}
    return (
        isinstance(answer, dict) and
        all(field in answer for field in required_fields) and
        isinstance(answer["user_id"], str) and
        isinstance(answer["question_id"], str) and
        isinstance(answer["answer"], bool) and
        isinstance(answer["timestamp"], (int, float))
    )

def lambda_handler(event, context):
    """
    AWS Lambda handler for submitting multiple answers.
    
    The function expects an event from API Gateway with a JSON body containing
    a list of answer objects. Each answer must have user_id, question_id,
    answer, and timestamp fields.
    
    Requires JWT authentication via Authorization: Bearer <token> header.
    
    Args:
        event: API Gateway event containing the request body
        context: Lambda context object (unused)
    
    Returns:
        API Gateway response with:
        - statusCode: 200 for success, 400 for bad request, 401 for auth errors, 500 for server error
        - body: JSON string containing success status and optional error message
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
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
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
        
        # Validate and get user ID
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
        # Parse the request body from API Gateway event
        # API Gateway wraps the body in a "body" field as a string
        body = json.loads(event["body"]) if "body" in event else event
        
        # Validate input is a list
        if not isinstance(body, list):
            return {
                "statusCode": 400,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                "body": json.dumps({
                    "success": False,
                    "error": "Input must be a list of answers"
                })
            }
        
        # Validate each answer's structure and types
        if not all(validate_answer(answer) for answer in body):
            return {
                "statusCode": 400,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                "body": json.dumps({
                    "success": False,
                    "error": "Each answer must contain user_id (str), question_id (str), answer (bool), and timestamp (number)"
                })
            }
        
        # Submit answers to DynamoDB and update user statistics
        # Get DynamoDB table resources
        answers_table_name = os.environ.get('ANSWERS_TABLE_NAME', 'truthbyte-answers')
        questions_table_name = os.environ.get('QUESTIONS_TABLE_NAME', 'truthbyte-questions')
        dynamodb = boto3.resource('dynamodb')
        answers_table = dynamodb.Table(answers_table_name)
        questions_table = dynamodb.Table(questions_table_name)
        
        # First, get question data to determine correct answers
        question_ids = [answer["question_id"] for answer in body]
        
        # Batch get questions to validate correct answers
        questions_response = dynamodb.batch_get_item(
            RequestItems={
                questions_table_name: {
                    'Keys': [{'id': qid} for qid in question_ids],
                    'ProjectionExpression': 'id, answer, tags'
                }
            }
        )
        
        questions_data = {
            q['id']: q for q in questions_response['Responses'].get(questions_table_name, [])
        }
        
        # Prepare batch write request for answers
        batch_items = []
        user_stats_updates = []
        
        for answer in body:
            question_id = answer["question_id"]
            user_answer = answer["answer"]
            
            # Get correct answer and tags for this question
            question_data = questions_data.get(question_id)
            if not question_data:
                continue  # Skip if question not found
            
            correct_answer = question_data.get('answer', False)
            question_tags = question_data.get('tags', [])
            
            # Format each answer as a DynamoDB item (include user_id from header)
            item = {
                "user_id": user_id,  # Use validated user_id from header
                "question_id": question_id,
                "answer": user_answer,
                "timestamp": answer["timestamp"],
                "correct_answer": correct_answer,
                "is_correct": user_answer == correct_answer
            }
            
            # Add to batch with PutRequest wrapper
            batch_items.append({
                'PutRequest': {
                    'Item': item
                }
            })
            
            # Prepare user stats update
            user_stats_updates.append({
                'question_id': question_id,
                'answer': user_answer,
                'correct_answer': correct_answer,
                'question_tags': question_tags
            })
        
        # Use batch_write_item to write multiple items in a single API call
        success = True
        if batch_items:
            response = dynamodb.batch_write_item(
                RequestItems={
                    answers_table.name: batch_items
                }
            )
            
            # Check for any unprocessed items
            if 'UnprocessedItems' in response and answers_table.name in response['UnprocessedItems']:
                success = False
        
        # Update user statistics for each answer
        if success:
            try:
                for stats_update in user_stats_updates:
                    update_user_stats(
                        user_id,
                        stats_update['question_id'],
                        stats_update['answer'],
                        stats_update['correct_answer']
                    )
            except Exception as e:
                print(f"❌ Error updating user stats: {str(e)}")
                # Don't fail the whole request if stats update fails
        
        # Return appropriate response based on submission result
        # API Gateway expects statusCode and body in the response
        return {
            "statusCode": 200 if success else 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
            },
            "body": json.dumps({
                "success": success
            })
        }
    except Exception as e:
        # Handle any unexpected errors
        print(f"❌ Error occurred: {str(e)}")
        print(f"📍 Error type: {type(e).__name__}")
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
            },
            "body": json.dumps({
                "success": False,
                "error": str(e)
            })
        } 