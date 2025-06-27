import json
import boto3
import os
import sys
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Any
from decimal import Decimal

# Add the shared directory to Python path for Lambda imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth_utils import verify_token, extract_user_id
from user_utils import get_or_create_user

# Initialize DynamoDB resources
dynamodb = boto3.resource('dynamodb')
questions_table_name = os.environ.get('QUESTIONS_TABLE_NAME', 'truthbyte-questions')
answers_table_name = os.environ.get('ANSWERS_TABLE_NAME', 'truthbyte-answers')
users_table_name = os.environ.get('USERS_TABLE_NAME', 'truthbyte-users')

questions_table = dynamodb.Table(questions_table_name)
answers_table = dynamodb.Table(answers_table_name)
users_table = dynamodb.Table(users_table_name)

class DecimalEncoder(json.JSONEncoder):
    """Custom JSON encoder to handle DynamoDB's Decimal type."""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def calculate_daily_score(answers: List[Dict], questions_data: Dict) -> Dict[str, Any]:
    """Calculate score and rank for daily mode"""
    correct_count = 0
    total_questions = len(answers)
    
    # Process each answer
    for answer in answers:
        question_id = answer.get('question_id')
        user_answer = answer.get('answer')
        
        question_data = questions_data.get(question_id, {})
        correct_answer = question_data.get('answer', False)
        
        if user_answer == correct_answer:
            correct_count += 1
    
    score_percentage = (correct_count / total_questions * 100) if total_questions > 0 else 0
    
    # Determine rank based on score
    if score_percentage == 100:
        rank = 'S'
    elif score_percentage >= 80:
        rank = 'A'
    elif score_percentage >= 70:
        rank = 'B'
    elif score_percentage >= 60:
        rank = 'C'
    else:
        rank = 'D'
    
    return {
        'correct_count': correct_count,
        'total_questions': total_questions,
        'score_percentage': Decimal(str(score_percentage)),  # Convert to Decimal for DynamoDB
        'rank': rank,
        'streak_eligible': score_percentage >= 70  # B rank or better for streak tiers
    }

def lambda_handler(event, context):
    """
    Handle daily mode answer submission.
    
    Expected body format:
    {
        "answers": [
            {
                "question_id": "q001",
                "answer": true,
                "timestamp": 1234567890
            },
            ...
        ],
        "date": "2024-01-15"
    }
    """
    try:
        # JWT Authentication
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
        
        # Get user ID
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
        
        # Parse request body
        try:
            body = json.loads(event['body'])
        except (json.JSONDecodeError, KeyError):
            return {
                'statusCode': 400,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                'body': json.dumps({'error': 'Invalid JSON in request body'})
            }
        
        answers = body.get('answers', [])
        date_str = body.get('date', datetime.now(timezone.utc).strftime('%Y-%m-%d'))
        
        if not answers:
            return {
                'statusCode': 400,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                'body': json.dumps({'error': 'No answers provided'})
            }
        
        # Check if user has already completed today's daily
        user_response = users_table.get_item(Key={'user_id': user_id})
        user_data = user_response.get('Item', {})
        daily_progress = user_data.get('daily_progress', {})
        
        if daily_progress.get(date_str, {}).get('completed', False):
            return {
                'statusCode': 400,
                'headers': {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
                },
                'body': json.dumps({'error': 'Daily challenge already completed for today'})
            }
        
        # Get question data to validate answers
        question_ids = [answer['question_id'] for answer in answers]
        questions_data = {}
        
        # Batch get questions
        if question_ids:
            batch_response = dynamodb.batch_get_item(
                RequestItems={
                    questions_table.name: {
                        'Keys': [{'id': qid} for qid in question_ids]
                    }
                }
            )
            
            for question in batch_response.get('Responses', {}).get(questions_table.name, []):
                questions_data[question['id']] = question
        
        # Calculate score and rank
        score_data = calculate_daily_score(answers, questions_data)
        
        # Store answers in answers table with daily flag
        batch_items = []
        for answer in answers:
            item = {
                'user_id': user_id,
                'question_id': answer['question_id'],
                'answer': answer['answer'],
                'timestamp': answer['timestamp'],
                'mode': 'daily',
                'date': date_str,
                'correct_answer': questions_data.get(answer['question_id'], {}).get('answer', False),
                'is_correct': answer['answer'] == questions_data.get(answer['question_id'], {}).get('answer', False)
            }
            
            batch_items.append({
                'PutRequest': {'Item': item}
            })
        
        # Write answers to database
        if batch_items:
            dynamodb.batch_write_item(
                RequestItems={
                    answers_table.name: batch_items
                }
            )
        
        # Update user's daily progress
        current_time = datetime.now(timezone.utc).isoformat()
        daily_progress[date_str] = {
            'completed': True,
            'score': score_data['score_percentage'],
            'rank': score_data['rank'],
            'correct_count': score_data['correct_count'],
            'total_questions': score_data['total_questions'],
            'answers': answers,
            'completed_at': current_time,
            'streak_eligible': score_data['streak_eligible']
        }
        
        # Calculate streak
        streak_count = 0
        check_date = datetime.strptime(date_str, '%Y-%m-%d')
        while True:
            check_str = check_date.strftime('%Y-%m-%d')
            day_data = daily_progress.get(check_str)
            if day_data and day_data.get('completed', False):
                streak_count += 1
                # Use timedelta to properly handle month boundaries
                check_date = check_date - timedelta(days=1)
            else:
                break
            if streak_count > 365:  # Safety limit
                break
        
        # Get current best streak to calculate new best
        current_best = user_data.get('best_daily_streak', 0)
        new_best = max(int(current_best), streak_count)
        
        # Update user record  
        users_table.update_item(
            Key={'user_id': user_id},
            UpdateExpression="""
                SET daily_progress = :daily_progress,
                    current_daily_streak = :current_streak,
                    best_daily_streak = :best_streak,
                    total_daily_games = if_not_exists(total_daily_games, :zero) + :one,
                    last_active = :last_active
            """,
            ExpressionAttributeValues={
                ':daily_progress': daily_progress,
                ':current_streak': Decimal(str(streak_count)),
                ':best_streak': Decimal(str(new_best)),
                ':zero': Decimal('0'),
                ':one': Decimal('1'),
                ':last_active': current_time
            }
        )
        
        return {
            'statusCode': 200,
            'headers': {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "https://truthbyte.voidtalker.com",
                "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-User-ID"
            },
            'body': json.dumps({
                'success': True,
                'score_data': score_data,
                'streak_count': streak_count,
                'best_streak': new_best,
                'date': date_str
            }, cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(f"Error in submit_daily_answers: {str(e)}")
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