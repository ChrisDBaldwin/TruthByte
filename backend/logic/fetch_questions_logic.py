import boto3
import random
import json
from typing import List, Dict, Any, Optional
from decimal import Decimal

# Initialize DynamoDB resource and table
# boto3.resource provides a higher-level interface than boto3.client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('truthbyte-questions')

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

def fetch_questions_logic(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Fetch questions from DynamoDB using either scan or query operations.
    
    DynamoDB Operations:
    - scan: Used when no tag filter is provided
        - Gets total count first to calculate random offset
        - Uses ExclusiveStartKey for pagination
        - Projects only needed attributes
    - query: Used when filtering by tag
        - Uses GSI (Global Secondary Index) on tags
        - Randomly orders results using ScanIndexForward
        - Fetches extra items to allow for random selection
    
    Args:
        event: API Gateway event containing query parameters
        
    Returns:
        API Gateway formatted response with questions or error
    """
    try:
        # Extract parameters from query string parameters
        query_params = event.get('queryStringParameters', {}) or {}
        
        # Get num_questions from query params, default to 7 if not provided or invalid
        try:
            num_questions = int(query_params.get('num_questions', 7))
            # Ensure num_questions is within reasonable bounds
            num_questions = max(1, min(num_questions, 20))  # Limit between 1 and 20
        except (ValueError, TypeError):
            num_questions = 7
            
        # Get tag from query params, default to None
        tag = query_params.get('tag')
        
        if not tag:
            # If no tag provided, use scan operation
            # First get total count to calculate random offset
            count_response = table.scan(
                Select='COUNT'  # Only get count, not items
            )
            total_items = count_response['Count']
            
            # Generate a random starting point for pagination
            start_idx = random.randint(0, max(0, total_items - num_questions))
            
            # Use scan with random starting point and limit
            # ProjectionExpression reduces data transfer by only getting needed fields
            response = table.scan(
                ProjectionExpression='id, question, answers, correct_answer, tags',
                Limit=num_questions,
                ExclusiveStartKey={'id': str(start_idx)} if start_idx > 0 else None
            )
        else:
            # Query by tag using GSI (Global Secondary Index)
            # GSI allows efficient querying on non-primary key attributes
            response = table.query(
                IndexName='tags-index',  # Name of the GSI
                KeyConditionExpression='tags = :tag_val',
                ExpressionAttributeValues={
                    ':tag_val': tag
                },
                ProjectionExpression='id, question, answers, correct_answer, tags',
                ScanIndexForward=random.choice([True, False]),  # Random order
                Limit=num_questions * 2  # Get extra items for random selection
            )
        
        items = response.get('Items', [])
        
        if not items:
            return {
                'statusCode': 404,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'  # Required for CORS
                },
                'body': json.dumps({
                    'error': f'No questions found{"for tag: " + tag if tag else ""}'
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
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'  # Required for CORS
            },
            'body': json.dumps({
                'questions': selected_questions,
                'count': len(selected_questions),
                'tag': tag,
                'requested_count': num_questions
            }, cls=DecimalEncoder)  # Use custom encoder for DynamoDB Decimal types
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'  # Required for CORS
            },
            'body': json.dumps({'error': f'Failed to fetch questions: {str(e)}'})
        }