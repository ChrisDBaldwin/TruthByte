import boto3
import json
import os
import sys
from collections import defaultdict
from typing import Dict, Any, List

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token

def lambda_handler(event, context):
    """
    AWS Lambda handler for fetching available categories.
    
    Returns a list of all available categories with question counts,
    sorted alphabetically. This is used for the category selection screen.
    
    Requires JWT authentication via Authorization: Bearer <token> header.
    
    Returns:
        API Gateway response with:
        - statusCode: 200 for success, 401 for auth errors, 500 for errors
        - body: JSON string containing categories list
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
        
        # Get DynamoDB tables
        dynamodb = boto3.resource('dynamodb')
        categories_table_name = os.environ.get('QUESTION_CATEGORIES_TABLE_NAME', 'truthbyte-question-categories')
        categories_table = dynamodb.Table(categories_table_name)
        
        # Scan the categories table to get all categories and their question counts
        # Note: This is an expensive operation for large datasets, but reasonable for category metadata
        category_counts = defaultdict(int)
        
        try:
            # Scan the question-categories table to count questions per category
            response = categories_table.scan(
                ProjectionExpression='category'
            )
            
            for item in response.get('Items', []):
                category = item.get('category')
                if category:
                    category_counts[category] += 1
            
            # Handle pagination if needed
            while 'LastEvaluatedKey' in response:
                response = categories_table.scan(
                    ProjectionExpression='category',
                    ExclusiveStartKey=response['LastEvaluatedKey']
                )
                for item in response.get('Items', []):
                    category = item.get('category')
                    if category:
                        category_counts[category] += 1
                        
        except Exception as e:
            print(f"Error scanning categories table: {str(e)}")
            # Fallback to a basic list if scanning fails
            category_counts = {
                'general': 100,
                'science': 75,
                'history': 50,
                'geography': 40,
                'sports': 30,
                'entertainment': 25,
                'politics': 20,
                'business': 15,
                'health': 10,
                'education': 8
            }
        
        # Convert to sorted list of category objects
        categories = []
        for category, count in sorted(category_counts.items()):
            categories.append({
                'name': category,
                'count': count,
                'display_name': category.replace('_', ' ').title()
            })
        
        return {
            'statusCode': 200,
            'headers': {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
            },
            'body': json.dumps({
                'categories': categories,
                'total_categories': len(categories),
                'total_questions': sum(category_counts.values())
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
                "error": f"Error fetching categories: {str(e)}"
            })
        } 