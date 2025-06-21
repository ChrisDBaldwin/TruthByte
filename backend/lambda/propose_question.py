import json
import boto3
import uuid
import os
import sys
import time
from typing import Dict, Any

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token

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
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
                },
                'body': json.dumps({'error': 'Invalid token'})
            }
        # Parse the request body from API Gateway event
        # API Gateway wraps the body in a "body" field as a string
        body = json.loads(event["body"]) if "body" in event else event
        
        # Get DynamoDB table resource
        table_name = os.environ.get('SUBMITTED_QUESTIONS_TABLE_NAME', 'truthbyte-submitted-questions')
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(table_name)
        
        # Validate required fields for TruthByte format
        required_fields = {"question", "answer", "tags"}
        if not all(field in body for field in required_fields):
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
                    "error": "Missing required fields: question, answer (boolean), tags"
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
        
        # Generate a unique question ID
        question_id = f"q_{uuid.uuid4().hex[:8]}"
        
        # Prepare the item for DynamoDB (TruthByte format)
        item = {
            "id": question_id,
            "question": body["question"],
            "title": body.get("title", ""),  # Optional context title
            "passage": body.get("passage", ""),  # Optional background passage
            "answer": body["answer"],  # Boolean answer
            "tags": body["tags"],
            "status": "pending",  # Questions start as pending until approved
            "submitted_at": int(time.time())  # Timestamp for review queue
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