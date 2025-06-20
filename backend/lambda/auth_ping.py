import sys
import os

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token
import json

def lambda_handler(event, context):
    """
    AWS Lambda handler for validating JWT tokens.
    
    This debug endpoint validates a JWT token and returns the decoded payload.
    Useful for verifying that token handling is working correctly.
    
    Expected headers:
    - Authorization: Bearer <token>
    
    Returns:
        API Gateway response with:
        - statusCode: 200 for valid token, 401 for invalid/missing token
        - headers: Content-Type and CORS headers
        - body: JSON string containing decoded payload or error message
    """
    try:
        # Get Authorization header
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
                'body': json.dumps({
                    'error': 'Missing or invalid Authorization header'
                })
            }
        
        # Extract token from Bearer header
        token = auth_header[len("Bearer "):]
        
        # Verify token
        payload = verify_token(token)
        
        return {
            'statusCode': 200,
            'headers': {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
            },
            'body': json.dumps({
                'valid': True,
                'payload': payload,
                'message': 'Token is valid'
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 401,
            'headers': {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
            },
            'body': json.dumps({
                'valid': False,
                'error': f'Invalid token: {str(e)}'
            })
        } 