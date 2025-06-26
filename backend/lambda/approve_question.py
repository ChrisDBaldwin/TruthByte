import boto3
import json
import os
import sys
import time
from typing import Dict, Any
from decimal import Decimal

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token, extract_user_id
from user_utils import get_or_create_user

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')
submitted_questions_table_name = os.environ.get('SUBMITTED_QUESTIONS_TABLE_NAME', 'truthbyte-submitted-questions')
questions_table_name = os.environ.get('QUESTIONS_TABLE_NAME', 'truthbyte-questions')
categories_table_name = os.environ.get('QUESTION_CATEGORIES_TABLE_NAME', 'truthbyte-question-categories')

submitted_questions_table = dynamodb.Table(submitted_questions_table_name)
questions_table = dynamodb.Table(questions_table_name)
categories_table = dynamodb.Table(categories_table_name)

class DecimalEncoder(json.JSONEncoder):
    """Custom JSON encoder to handle DynamoDB's Decimal type."""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    Admin function to approve or reject submitted questions.
    
    POST body should contain:
    - question_id: ID of submitted question to review
    - action: 'approve' or 'reject'
    - reviewer_notes: Optional notes from reviewer
    
    When approving:
    - Moves question to main questions table
    - Updates submitted question status and accepted flag
    - TODO: Award points/rewards to submitter
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
        
        # Get reviewer user ID
        try:
            reviewer_id = extract_user_id(headers)
            reviewer_user = get_or_create_user(reviewer_id)
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
        
        # TODO: Add admin role check here
        # For now, any authenticated user can approve (obviously this needs to be restricted)
        
        # Parse request body
        body = json.loads(event["body"]) if "body" in event else event
        
        # Validate required fields
        required_fields = {"question_id", "action"}
        if not all(field in body for field in required_fields):
            return {
                'statusCode': 400,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                'body': json.dumps({'error': f'Missing required fields: {required_fields}'})
            }
        
        question_id = body["question_id"]
        action = body["action"].lower()
        reviewer_notes = body.get("reviewer_notes", "")
        
        if action not in ["approve", "reject"]:
            return {
                'statusCode': 400,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                'body': json.dumps({'error': 'Action must be "approve" or "reject"'})
            }
        
        # Get the submitted question
        response = submitted_questions_table.get_item(Key={'id': question_id})
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                'body': json.dumps({'error': 'Question not found'})
            }
        
        submitted_question = response['Item']
        
        # Check if already processed
        if submitted_question.get('status') != 'pending':
            return {
                'statusCode': 400,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                'body': json.dumps({'error': f'Question already {submitted_question.get("status")}'})
            }
        
        # Update the submitted question record
        current_time = int(time.time())
        update_params = {
            'Key': {'id': question_id},
            'UpdateExpression': 'SET #status = :status, accepted = :accepted, reviewed_at = :reviewed_at, reviewer_id = :reviewer_id',
            'ExpressionAttributeNames': {'#status': 'status'},
            'ExpressionAttributeValues': {
                ':status': action + 'd',  # approved or rejected
                ':accepted': action == 'approve',
                ':reviewed_at': current_time,
                ':reviewer_id': reviewer_id
            }
        }
        
        if reviewer_notes:
            update_params['UpdateExpression'] += ', reviewer_notes = :reviewer_notes'
            update_params['ExpressionAttributeValues'][':reviewer_notes'] = reviewer_notes
        
        submitted_questions_table.update_item(**update_params)
        
        result = {'action': action, 'question_id': question_id}
        
        if action == 'approve':
            # Move question to main questions table
            # Generate new question ID for main table
            import uuid
            main_question_id = str(uuid.uuid4())
            
            # Prepare question for main table
            approved_question = {
                'id': main_question_id,
                'question': submitted_question['question'],
                'title': submitted_question.get('title', ''),
                'passage': submitted_question.get('passage', ''),
                'answer': submitted_question['answer'],
                'categories': submitted_question.get('categories', submitted_question.get('tags', ['general'])),
                'difficulty': submitted_question.get('difficulty', 3),
                'created_at': current_time,
                'source': 'user_submission',
                'original_author': submitted_question.get('author', 'unknown')
            }
            
            # Add to main questions table
            questions_table.put_item(Item=approved_question)
            
            # Add category mappings
            categories = approved_question.get('categories', ['general'])
            for category in categories:
                categories_table.put_item(
                    Item={
                        'category': category,
                        'question_id': main_question_id
                    }
                )
            
            result['approved_question_id'] = main_question_id
            result['message'] = 'Question approved and added to main question pool'
            
            # TODO: Award points to the submitter
            # This could be done here or via a separate reward system
            
        else:
            result['message'] = 'Question rejected'
        
        return {
            'statusCode': 200,
            'headers': {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
            },
            'body': json.dumps(result, cls=DecimalEncoder)
        }
        
    except Exception as e:
        # Log the error for debugging
        print(f"Error in approve_question lambda: {str(e)}")
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