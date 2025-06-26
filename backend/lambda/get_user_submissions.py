import boto3
import json
import os
import sys
from typing import Dict, Any
from decimal import Decimal

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token, extract_user_id
from user_utils import get_or_create_user

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')
submitted_questions_table_name = os.environ.get('SUBMITTED_QUESTIONS_TABLE_NAME', 'truthbyte-submitted-questions')
submitted_questions_table = dynamodb.Table(submitted_questions_table_name)

class DecimalEncoder(json.JSONEncoder):
    """Custom JSON encoder to handle DynamoDB's Decimal type."""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    Get user's submitted questions and their status for tracking rewards.
    
    Supports both getting specific user submissions and moderation queries.
    
    Query parameters:
    - user_id: Get submissions for specific user (optional, defaults to authenticated user)
    - status: Filter by status (pending/approved/rejected) (optional)
    - limit: Limit number of results (optional, default: 20, max: 100)
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
        
        # Get authenticated user ID
        try:
            authenticated_user_id = extract_user_id(headers)
            authenticated_user = get_or_create_user(authenticated_user_id)
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
        
        # Extract parameters from query string
        query_params = event.get('queryStringParameters', {}) or {}
        
        # Get target user ID (defaults to authenticated user)
        target_user_id = query_params.get('user_id', authenticated_user_id)
        
        # Security check: only allow users to see their own submissions unless they have admin privileges
        # For now, only allow users to see their own submissions
        if target_user_id != authenticated_user_id:
            # TODO: Add admin check here when admin roles are implemented
            return {
                'statusCode': 403,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                'body': json.dumps({'error': 'Access denied: can only view your own submissions'})
            }
        
        # Get filter parameters
        status_filter = query_params.get('status')
        try:
            limit = int(query_params.get('limit', 20))
            limit = max(1, min(limit, 100))  # Clamp between 1 and 100
        except (ValueError, TypeError):
            limit = 20
        
        # Query user submissions using the author-index
        query_params_dynamo = {
            'IndexName': 'author-index',
            'KeyConditionExpression': 'author = :author_val',
            'ExpressionAttributeValues': {
                ':author_val': target_user_id
            },
            'ScanIndexForward': False,  # Most recent first
            'Limit': limit
        }
        
        # Add status filter if specified
        if status_filter:
            query_params_dynamo['FilterExpression'] = '#status = :status_val'
            query_params_dynamo['ExpressionAttributeNames'] = {'#status': 'status'}
            query_params_dynamo['ExpressionAttributeValues'][':status_val'] = status_filter
        
        # Execute query
        response = submitted_questions_table.query(**query_params_dynamo)
        
        submissions = response.get('Items', [])
        
        # Calculate summary statistics
        total_submissions = len(submissions)
        accepted_count = len([s for s in submissions if s.get('accepted', False)])
        pending_count = len([s for s in submissions if s.get('status') == 'pending'])
        
        # Format response
        return {
            'statusCode': 200,
            'headers': {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
            },
            'body': json.dumps({
                'submissions': submissions,
                'summary': {
                    'total_submissions': total_submissions,
                    'accepted_count': accepted_count,
                    'pending_count': pending_count,
                    'acceptance_rate': round(accepted_count / total_submissions * 100, 1) if total_submissions > 0 else 0
                },
                'user_id': target_user_id,
                'requested_limit': limit
            }, cls=DecimalEncoder)
        }
        
    except Exception as e:
        # Log the error for debugging
        print(f"Error in get_user_submissions lambda: {str(e)}")
        print(f"Event: {json.dumps(event)}")
        
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
            },
            "body": json.dumps({
                "error": f"Unexpected error in lambda handler: {str(e)}"
            })
        } 