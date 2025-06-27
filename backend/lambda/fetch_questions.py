import boto3
import random
import json
import os
import sys
from typing import Dict, Any
from decimal import Decimal
from boto3.dynamodb.conditions import Attr, Key

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token, extract_user_id
from user_utils import get_or_create_user

# Initialize DynamoDB resource and tables
# boto3.resource provides a higher-level interface than boto3.client
dynamodb = boto3.resource('dynamodb')
questions_table_name = os.environ.get('QUESTIONS_TABLE_NAME', 'dev-truthbyte-questions')
categories_table_name = os.environ.get('QUESTION_CATEGORIES_TABLE_NAME', 'dev-truthbyte-question-categories')
questions_table = dynamodb.Table(questions_table_name)

# Handle the case where the categories table might not exist yet (backwards compatibility)
try:
    categories_table = dynamodb.Table(categories_table_name)
    # Test if table exists by checking its status
    categories_table.table_status
    USE_CATEGORIES_TABLE = True
    print(f"Categories table '{categories_table_name}' is available")
except Exception as e:
    USE_CATEGORIES_TABLE = False
    categories_table = None
    print(f"Categories table '{categories_table_name}' is not available: {e}")

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
            
        # Get category from query params, default to 'general' for efficient querying
        category = query_params.get('category', 'general')
        
        # Debug: Log the actual category parameter received
        print(f"Received category parameter: '{category}' (type: {type(category)})")
        print(f"Query params: {query_params}")
        print(f"Requested {num_questions} questions for category: {category}")
        
        # Get difficulty filter from query params (optional)
        difficulty = query_params.get('difficulty')
        if difficulty:
            try:
                difficulty = int(difficulty)
                if difficulty < 1 or difficulty > 5:
                    difficulty = None
            except (ValueError, TypeError):
                difficulty = None
        
        # Use DynamoDB scan with FilterExpression for category filtering
        if category != 'general':
            print(f"Filtering for specific category: {category}")
            
            # Use FilterExpression to filter by category during scan
            # This handles both simple string arrays and DynamoDB typed format
            scan_params = {
                'FilterExpression': Attr('categories').contains(category),
                'Limit': num_questions * 50  # Much higher limit since we're filtering
            }
            
            try:
                response = questions_table.scan(**scan_params)
                items = response.get('Items', [])
                print(f"DynamoDB FilterExpression scan returned {len(items)} items for category: {category}")
                
                # If we didn't get enough items, try multiple scans
                scan_count = 1
                while len(items) < num_questions and scan_count < 3:
                    print(f"Not enough items ({len(items)}), performing additional scan #{scan_count + 1}")
                    
                    # Continue scanning from where we left off
                    if 'LastEvaluatedKey' in response:
                        scan_params['ExclusiveStartKey'] = response['LastEvaluatedKey']
                    else:
                        # No more items to scan, break
                        break
                        
                    response = questions_table.scan(**scan_params)
                    additional_items = response.get('Items', [])
                    items.extend(additional_items)
                    scan_count += 1
                    print(f"Additional scan returned {len(additional_items)} items, total now: {len(items)}")
                
            except Exception as e:
                print(f"Error with FilterExpression scan: {e}")
                print("Falling back to full scan with Python filtering")
                # Fall back to full scan with Python filtering
                response = questions_table.scan(Limit=num_questions * 50)
                all_items = response.get('Items', [])
                
                # Filter in Python
                items = []
                for item in all_items:
                    categories = item.get('categories', [])
                    if isinstance(categories, list):
                        # Check if category matches any item in the categories list
                        for cat in categories:
                            if isinstance(cat, str) and cat == category:
                                items.append(item)
                                break
                            elif isinstance(cat, dict) and cat.get('S') == category:
                                items.append(item)
                                break
                
                print(f"Python filtering found {len(items)} items for category: {category}")
        else:
            print(f"Using main table scan for general category")
            # For 'general' category, scan without filtering
            scan_params = {
                'Limit': num_questions * 10
            }
            
            response = questions_table.scan(**scan_params)
            items = response.get('Items', [])
        
        # Debug logging for troubleshooting
        print(f"Retrieved {len(items)} items for category: {category}")
        if items and len(items) > 0:
            # Log first item structure for debugging
            sample_item = items[0]
            print(f"Sample item ID: {sample_item.get('id', 'unknown')}")
            print(f"Sample item categories: {sample_item.get('categories', 'NOT_FOUND')}")
        
        # Filter by difficulty if specified
        if difficulty is not None:
            items = [item for item in items if item.get('difficulty') == difficulty]
        
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
                    'error': f'No questions found for category: {category}' + (f' with difficulty: {difficulty}' if difficulty else ''),
                    'debug_info': {
                        'scan_limit': scan_params.get('Limit', 'none'),
                        'filter_applied': 'FilterExpression' in scan_params,
                        'total_scanned_items': len(response.get('Items', [])),
                        'categories_table_available': USE_CATEGORIES_TABLE,
                        'requested_category': category,
                        'category_is_general': category == 'general',
                        'python_filter_applied': category != 'general'
                    }
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
                'category': category,
                'difficulty': difficulty,
                'requested_count': num_questions
            }, cls=DecimalEncoder)  # Use custom encoder for DynamoDB Decimal types
        }
        
    except Exception as e:
        # Log the error for debugging
        print(f"Error in fetch_questions lambda: {str(e)}")
        print(f"Event: {json.dumps(event)}")
        print(f"Categories table exists: {USE_CATEGORIES_TABLE}")
        
        # Capture more debugging context if available
        debug_context = {
            "categories_table_available": USE_CATEGORIES_TABLE,
            "category_requested": query_params.get('category', 'general') if 'query_params' in locals() else 'unknown',
            "exception_type": type(e).__name__,
            "exception_details": str(e)
        }
        
        # Add scan parameters info if available
        if 'scan_params' in locals():
            debug_context["scan_params_keys"] = list(scan_params.keys())
            debug_context["has_filter_expression"] = 'FilterExpression' in scan_params
        
        print(f"Debug context: {json.dumps(debug_context)}")
        
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
                "error": f"Unexpected error in lambda handler: {str(e)}",
                "debug_info": debug_context
            })
        } 