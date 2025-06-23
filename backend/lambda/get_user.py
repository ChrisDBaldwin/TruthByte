import json
import boto3
import os
import sys
from typing import Dict, Any

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token, extract_user_id
from user_utils import get_or_create_user, DecimalEncoder

def lambda_handler(event, context):
    """
    AWS Lambda handler for getting user data.
    
    The function expects an event from API Gateway and returns user data
    including user_id, trust_score, and tags.
    
    Requires JWT authentication via Authorization: Bearer <token> header.
    Requires X-User-ID header.
    
    Args:
        event: API Gateway event
        context: Lambda context object (unused)
    
    Returns:
        API Gateway response with:
        - statusCode: 200 for success, 400 for bad request, 401 for auth errors, 500 for server error
        - body: JSON string containing user data or error message
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
            # Get or create user record
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
        
        # Return user data
        return {
            'statusCode': 200,
            'headers': {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
            },
            'body': json.dumps({
                'user_id': user['user_id'],
                'trust_score': user['trust_score'],
                'created_at': user['created_at'],
                'last_active': user['last_active'],
                'total_questions_answered': user['total_questions_answered'],
                'correct_answers': user['correct_answers'],
                'tags': user['tags']
            }, cls=DecimalEncoder)
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
                "error": str(e)
            })
        } 