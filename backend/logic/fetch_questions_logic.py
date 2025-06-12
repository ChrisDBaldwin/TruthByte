import boto3
import random
import json
from typing import List, Dict, Any, Optional
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('truthbyte-questions')

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)  # Convert Decimal to float
        return super(DecimalEncoder, self).default(obj)

def fetch_questions_logic(event: Dict[str, Any]) -> Dict[str, Any]:
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
            # If no tag provided, get a count of items to generate random starting point
            count_response = table.scan(
                Select='COUNT'
            )
            total_items = count_response['Count']
            
            # Generate a random starting point
            start_idx = random.randint(0, max(0, total_items - num_questions))
            
            # Use scan with random starting point and limit
            response = table.scan(
                ProjectionExpression='id, question, answers, correct_answer, tags',
                Limit=num_questions,
                ExclusiveStartKey={'id': str(start_idx)} if start_idx > 0 else None
            )
        else:
            # Query by tag using GSI
            response = table.query(
                IndexName='tags-index',
                KeyConditionExpression='tags = :tag_val',
                ExpressionAttributeValues={
                    ':tag_val': tag
                },
                ProjectionExpression='id, question, answers, correct_answer, tags',
                ScanIndexForward=random.choice([True, False]),
                Limit=num_questions * 2
            )
        
        items = response.get('Items', [])
        
        if not items:
            return {
                'statusCode': 404,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'  # Add CORS header
                },
                'body': json.dumps({
                    'error': f'No questions found{"for tag: " + tag if tag else ""}'
                })
            }
        
        # Randomly select from the retrieved items
        selected_questions = random.sample(
            items,
            min(num_questions, len(items))
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'  # Add CORS header
            },
            'body': json.dumps({
                'questions': selected_questions,
                'count': len(selected_questions),
                'tag': tag,
                'requested_count': num_questions
            }, cls=DecimalEncoder)
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'  # Add CORS header
            },
            'body': json.dumps({'error': f'Failed to fetch questions: {str(e)}'})
        }