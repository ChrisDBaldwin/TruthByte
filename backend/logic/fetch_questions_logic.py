import boto3
import random
import json
from typing import List, Dict, Any
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('truthbyte-questions')

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)  # Convert Decimal to float
        return super(DecimalEncoder, self).default(obj)

def fetch_questions_logic(input_data, num_questions: int = 7, tag: str = None) -> Dict[str, Any]:
    try:
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
            # Query by tag using GSI (Global Secondary Index)
            # Note: You'll need to create a GSI on the 'tags' attribute
            response = table.query(
                IndexName='tags-index',  # You'll need to create this GSI
                KeyConditionExpression='tags = :tag_val',
                ExpressionAttributeValues={
                    ':tag_val': tag
                },
                ProjectionExpression='id, question, answers, correct_answer, tags',
                # Add random sampling using a random sort key range
                ScanIndexForward=random.choice([True, False]),  # Random direction
                Limit=num_questions * 2  # Get more items than needed to allow for random selection
            )
        
        items = response.get('Items', [])
        
        if not items:
            return {
                'statusCode': 404,
                'headers': {'Content-Type': 'application/json'},
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
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'questions': selected_questions,
                'count': len(selected_questions),
                'tag': tag
            }, cls=DecimalEncoder)  # Use custom encoder instead of default=str
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': f'Failed to fetch questions: {str(e)}'})
        }