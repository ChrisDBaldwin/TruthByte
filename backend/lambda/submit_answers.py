import json
import boto3
import os
import sys
from typing import List, Dict, Any

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token

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
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
                },
                'body': json.dumps({'error': 'Invalid token'})
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
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
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
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
                },
                "body": json.dumps({
                    "success": False,
                    "error": "Each answer must contain user_id (str), question_id (str), answer (bool), and timestamp (number)"
                })
            }
        
        # Submit answers to DynamoDB
        # Get DynamoDB table resource
        table_name = os.environ.get('ANSWERS_TABLE_NAME', 'truthbyte-answers')
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table_name)
        
        # Prepare batch write request
        # Each item needs to be wrapped in a PutRequest for batch_write_item
        batch_items = []
        for answer in body:
            # Format each answer as a DynamoDB item
            item = {
                "user_id": answer["user_id"],
                "question_id": answer["question_id"],
                "answer": answer["answer"],
                "timestamp": answer["timestamp"],
            }
            # Add to batch with PutRequest wrapper
            batch_items.append({
                'PutRequest': {
                    'Item': item
                }
            })
        
        # Use batch_write_item to write multiple items in a single API call
        # This is more efficient than individual put_item calls
        # Note: DynamoDB has a limit of 25 items per batch_write_item call
        response = dynamodb.batch_write_item(
            RequestItems={
                table.name: batch_items
            }
        )
        
        # Check for any unprocessed items
        # If DynamoDB couldn't process all items, they'll be in UnprocessedItems
        # This could happen due to throttling or other temporary issues
        success = True
        if 'UnprocessedItems' in response and table.name in response['UnprocessedItems']:
            success = False
        
        # Return appropriate response based on submission result
        # API Gateway expects statusCode and body in the response
        return {
            "statusCode": 200 if success else 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
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
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
            },
            "body": json.dumps({
                "success": False,
                "error": str(e)
            })
        } 