import boto3
import json
import os
import sys
import hashlib
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List
from decimal import Decimal
from boto3.dynamodb.conditions import Attr

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token, extract_user_id
from user_utils import get_or_create_user

# Initialize DynamoDB resource and tables
dynamodb = boto3.resource('dynamodb')
questions_table_name = os.environ.get('QUESTIONS_TABLE_NAME', 'truthbyte-questions')
questions_table = dynamodb.Table(questions_table_name)
users_table_name = os.environ.get('USERS_TABLE_NAME', 'truthbyte-users')
users_table = dynamodb.Table(users_table_name)

class DecimalEncoder(json.JSONEncoder):
    """Custom JSON encoder to handle DynamoDB's Decimal type."""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def get_daily_seed(date_str: str) -> int:
    """Generate deterministic seed based on date"""
    # Create a hash of the date string to get a consistent daily seed
    hash_obj = hashlib.sha256(f"truthbyte-daily-{date_str}".encode())
    # Convert first 8 bytes to integer for seed
    return int.from_bytes(hash_obj.digest()[:8], byteorder='big')

def deterministic_sample(items: List[Any], sample_size: int, seed: int) -> List[Any]:
    """Deterministically sample items using a seed"""
    import random
    rng = random.Random(seed)
    return rng.sample(items, min(sample_size, len(items)))

def get_user_daily_progress(user_id: str, date_str: str) -> Dict[str, Any]:
    """Get user's progress for a specific date"""
    try:
        response = users_table.get_item(Key={'user_id': user_id})
        user_data = response.get('Item', {})
        
        daily_progress = user_data.get('daily_progress', {})
        return daily_progress.get(date_str, {
            'completed': False,
            'score': 0,
            'answers': [],
            'completed_at': None
        })
    except Exception as e:
        print(f"Error getting daily progress: {str(e)}")
        return {
            'completed': False,
            'score': 0,
            'answers': [],
            'completed_at': None
        }

def lambda_handler(event, context):
    """
    AWS Lambda handler for fetching daily questions.
    
    This function provides deterministic daily questions that are the same for all users
    on a given date. Questions are selected using a date-based seed for consistency.
    
    Returns 10 questions for the daily challenge, along with user's progress for today.
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
        
        # Get current date in UTC
        today = datetime.now(timezone.utc)
        date_str = today.strftime('%Y-%m-%d')
        
        # Check if user has already completed today's daily
        daily_progress = get_user_daily_progress(user_id, date_str)
        
        # Get all questions for deterministic selection
        # Scan with a reasonable limit - we'll sample from these
        scan_params = {
            'Limit': 500,  # Get a good pool of questions to sample from
            'FilterExpression': Attr('difficulty').between(1, 4)  # Avoid hardest questions for daily
        }
        
        response = questions_table.scan(**scan_params)
        all_questions = response.get('Items', [])
        
        # Continue scanning if we have more questions
        while 'LastEvaluatedKey' in response and len(all_questions) < 1000:
            scan_params['ExclusiveStartKey'] = response['LastEvaluatedKey']
            response = questions_table.scan(**scan_params)
            all_questions.extend(response.get('Items', []))
        
        if len(all_questions) < 10:
            return {
                'statusCode': 404,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                'body': json.dumps({'error': 'Not enough questions available for daily challenge'})
            }
        
        # Deterministically select 10 questions for today
        daily_seed = get_daily_seed(date_str)
        daily_questions = deterministic_sample(all_questions, 10, daily_seed)
        
        # Calculate user's current streak
        streak_info = calculate_user_streak(user_id)
        
        return {
            'statusCode': 200,
            'headers': {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
            },
            'body': json.dumps({
                'questions': daily_questions,
                'date': date_str,
                'daily_progress': daily_progress,
                'streak_info': streak_info,
                'total_questions': 10
            }, cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(f"Error in fetch_daily_questions: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
            },
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        }

def calculate_user_streak(user_id: str) -> Dict[str, Any]:
    """Calculate user's current daily streak"""
    try:
        response = users_table.get_item(Key={'user_id': user_id})
        user_data = response.get('Item', {})
        
        daily_progress = user_data.get('daily_progress', {})
        
        # Get current date and work backwards to find streak
        today = datetime.now(timezone.utc)
        current_streak = 0
        best_streak = user_data.get('best_daily_streak', 0)
        
        # Check each day backwards from today until we find a gap
        check_date = today
        while True:
            date_str = check_date.strftime('%Y-%m-%d')
            day_progress = daily_progress.get(date_str, {})
            
            if day_progress.get('completed', False):
                current_streak += 1
                check_date = check_date - timedelta(days=1)
            else:
                break
            
            # Safety limit to prevent infinite loops
            if current_streak > 365:
                break
        
        return {
            'current_streak': current_streak,
            'best_streak': max(best_streak, current_streak),
            'today_completed': daily_progress.get(today.strftime('%Y-%m-%d'), {}).get('completed', False)
        }
        
    except Exception as e:
        print(f"Error calculating streak: {str(e)}")
        return {
            'current_streak': 0,
            'best_streak': 0,
            'today_completed': False
        } 