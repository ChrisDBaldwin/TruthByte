import boto3
import json
import os
from datetime import datetime
from typing import Dict, Any, Optional
from decimal import Decimal

# Initialize DynamoDB resource
dynamodb = boto3.resource('dynamodb')
users_table_name = os.environ.get('USERS_TABLE_NAME', 'truthbyte-users')
users_table = dynamodb.Table(users_table_name)

def get_or_create_user(user_id: str) -> Dict[str, Any]:
    """
    Get user record from DynamoDB, creating it if it doesn't exist.
    
    Args:
        user_id: UUID string for the user
        
    Returns:
        Dict containing user data
    """
    try:
        # Try to get existing user
        response = users_table.get_item(Key={'user_id': user_id})
        
        if 'Item' in response:
            return response['Item']
        
        # User doesn't exist, create new record
        current_time = datetime.utcnow().isoformat()
        new_user = {
            'user_id': user_id,
            'trust_score': Decimal('0'),
            'created_at': current_time,
            'last_active': current_time,
            'total_questions_answered': Decimal('0'),
            'correct_answers': Decimal('0'),
            'daily_progress': {},  # Track daily challenge progress by date
            'current_daily_streak': Decimal('0'),
            'best_daily_streak': Decimal('0'),
            'total_daily_games': Decimal('0')
        }
        
        users_table.put_item(Item=new_user)
        return new_user
        
    except Exception as e:
        print(f"❌ Error in get_or_create_user: {str(e)}")
        raise

def update_user_stats(user_id: str, question_id: str, answer: bool, correct_answer: bool) -> Dict[str, Any]:
    """
    Update user statistics based on their answer.
    
    Args:
        user_id: UUID string for the user
        question_id: Question ID that was answered
        answer: User's answer (True/False)
        correct_answer: The correct answer
        
    Returns:
        Dict containing updated user data
    """
    try:
        current_time = datetime.now(datetime.UTC)
        is_correct = answer == correct_answer
        
        # Use update_item with atomic operations
        update_expression = "SET last_active = :last_active, total_questions_answered = total_questions_answered + :one"
        expression_values = {
            ':last_active': current_time,
            ':one': Decimal('1')
        }
        
        # If answer is correct, increment trust_score and correct_answers
        if is_correct:
            update_expression += ", trust_score = trust_score + :one, correct_answers = correct_answers + :one"
        
        response = users_table.update_item(
            Key={'user_id': user_id},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_values,
            ReturnValues='ALL_NEW'
        )
        
        return response['Attributes']
        
    except Exception as e:
        print(f"❌ Error in update_user_stats: {str(e)}")
        raise

def get_user(user_id: str) -> Optional[Dict[str, Any]]:
    """
    Get user record from DynamoDB.
    
    Args:
        user_id: UUID string for the user
        
    Returns:
        Dict containing user data or None if not found
    """
    try:
        response = users_table.get_item(Key={'user_id': user_id})
        return response.get('Item')
    except Exception as e:
        print(f"❌ Error in get_user: {str(e)}")
        raise

class DecimalEncoder(json.JSONEncoder):
    """
    Custom JSON encoder to handle DynamoDB's Decimal type.
    """
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def migrate_user_to_daily_progress(user_id: str) -> Dict[str, Any]:
    """
    Migrate an existing user to have daily progress fields and remove deprecated tags.
    This is optional since the code already handles missing fields gracefully.
    
    Args:
        user_id: UUID string for the user
        
    Returns:
        Dict containing updated user data
    """
    try:
        # Update user record to add daily progress fields and remove tags if they exist
        response = users_table.update_item(
            Key={'user_id': user_id},
            UpdateExpression="""
                SET daily_progress = if_not_exists(daily_progress, :empty_dict),
                    current_daily_streak = if_not_exists(current_daily_streak, :zero),
                    best_daily_streak = if_not_exists(best_daily_streak, :zero),
                    total_daily_games = if_not_exists(total_daily_games, :zero)
                REMOVE tags
            """,
            ExpressionAttributeValues={
                ':empty_dict': {},
                ':zero': Decimal('0')
            },
            ReturnValues='ALL_NEW'
        )
        return response['Attributes']
    except Exception as e:
        # If REMOVE fails (tags doesn't exist), try without it
        try:
            response = users_table.update_item(
                Key={'user_id': user_id},
                UpdateExpression="""
                    SET daily_progress = if_not_exists(daily_progress, :empty_dict),
                        current_daily_streak = if_not_exists(current_daily_streak, :zero),
                        best_daily_streak = if_not_exists(best_daily_streak, :zero),
                        total_daily_games = if_not_exists(total_daily_games, :zero)
                """,
                ExpressionAttributeValues={
                    ':empty_dict': {},
                    ':zero': Decimal('0')
                },
                ReturnValues='ALL_NEW'
            )
            return response['Attributes']
        except Exception as e2:
            print(f"❌ Error in migrate_user_to_daily_progress: {str(e2)}")
            raise 