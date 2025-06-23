import boto3
import random
import json
import os
import sys
from typing import Dict, Any
from decimal import Decimal

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token, extract_user_id
from user_utils import get_or_create_user

# Initialize DynamoDB resource and tables
# boto3.resource provides a higher-level interface than boto3.client
dynamodb = boto3.resource('dynamodb')
questions_table_name = os.environ.get('QUESTIONS_TABLE_NAME', 'truthbyte-questions')
tags_table_name = os.environ.get('QUESTION_TAGS_TABLE_NAME', 'truthbyte-question-tags')
questions_table = dynamodb.Table(questions_table_name)
tags_table = dynamodb.Table(tags_table_name)

class DecimalEncoder(json.JSONEncoder):
    """
    Custom JSON encoder to handle DynamoDB's Decimal type.
    DynamoDB uses Decimal for numbers, but JSON doesn't support it.
    This encoder converts Decimal to float for JSON serialization.
    """
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)  # Convert Decimal to float
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    AWS Lambda handler for fetching questions from DynamoDB.
    
    The function expects an event from API Gateway with optional query parameters:
    - num_questions: Number of questions to fetch (default: 7, max: 20)
    - tag: Category tag to filter questions
    
    Requires JWT authentication via Authorization: Bearer <token> header.
    
    API Gateway Integration:
    - Query parameters are passed in event['queryStringParameters']
    - Response must include statusCode and body
    - CORS headers are required for browser access
    
    Returns:
        API Gateway response with:
        - statusCode: 200 for success, 404 for no questions, 401 for auth errors, 500 for errors
        - headers: Content-Type and CORS headers
        - body: JSON string containing questions or error message
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
        # Extract parameters from query string parameters
        query_params = event.get('queryStringParameters', {}) or {}
        
        # Get num_questions from query params, default to 7 if not provided or invalid
        try:
            num_questions = int(query_params.get('num_questions', 7))
            # Ensure num_questions is within reasonable bounds
            num_questions = max(1, min(num_questions, 20))  # Limit between 1 and 20
        except (ValueError, TypeError):
            num_questions = 7
            
        # Get tag from query params, default to 'general' for efficient querying
        tag = query_params.get('tag', 'general')
        
        # We always query by tag now to avoid expensive table scans
        # Every question should have a 'general' tag as a fallback
        
        # Query by tag using the separate tags table
        # First, get question IDs that have the requested tag
        tag_response = tags_table.query(
            KeyConditionExpression='tag = :tag_val',
            ExpressionAttributeValues={
                ':tag_val': tag
            },
            ProjectionExpression='question_id'
        )
        
        question_ids = [item['question_id'] for item in tag_response.get('Items', [])]
        
        if not question_ids:
            items = []
        else:
            # Randomly select question IDs to fetch
            selected_ids = random.sample(question_ids, min(num_questions * 2, len(question_ids)))
            
            # Batch get questions by ID
            items = []
            # DynamoDB batch_get_item has a limit of 100 items per request
            for i in range(0, len(selected_ids), 100):
                batch_ids = selected_ids[i:i+100]
                batch_response = dynamodb.batch_get_item(
                    RequestItems={
                        questions_table_name: {
                            'Keys': [{'id': qid} for qid in batch_ids],
                            'ProjectionExpression': 'id, question, title, passage, answer, tags'
                        }
                    }
                )
                items.extend(batch_response['Responses'].get(questions_table_name, []))
        
        if not items:
            return {
                'statusCode': 404,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                'body': json.dumps({
                    'error': f'No questions found for tag: {tag}'
                })
            }
        
        # Randomly select from the retrieved items
        # This ensures we don't always return the same questions
        selected_questions = random.sample(
            items,
            min(num_questions, len(items))
        )
        
        # Format response with API Gateway requirements
        return {
            'statusCode': 200,
            'headers': {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
            },
            'body': json.dumps({
                'questions': selected_questions,
                'count': len(selected_questions),
                'tag': tag,
                'requested_count': num_questions
            }, cls=DecimalEncoder)  # Use custom encoder for DynamoDB Decimal types
        }
        
    except Exception as e:
        # Return a proper error response with CORS headers
        # API Gateway requires specific response format
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