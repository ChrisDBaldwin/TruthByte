import sys
import os
import uuid
import time

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import create_token
import json

def lambda_handler(event, context):
    """
    AWS Lambda handler for issuing JWT tokens.
    
    This endpoint provides a JWT token for the frontend to use
    for authenticating subsequent API requests.
    
    Returns:
        API Gateway response with:
        - statusCode: 200 for success
        - headers: Content-Type and CORS headers
        - body: JSON string containing the JWT token
    """
    try:
        # Generate a unique session ID
        # Use timestamp + UUID for uniqueness
        timestamp = int(time.time())
        unique_id = str(uuid.uuid4())[:8]  # First 8 chars of UUID
        session_id = f"session-{timestamp}-{unique_id}"
        
        token = create_token(session_id)
        
        return {
            'statusCode': 200,
            'headers': {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
            },
            'body': json.dumps({
                'token': token,
                'session_id': session_id,
                'expires_in': 12 * 3600  # 12 hours in seconds
            })
        }
        
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
            },
            "body": json.dumps({
                "error": f"Error generating token: {str(e)}"
            })
        } 