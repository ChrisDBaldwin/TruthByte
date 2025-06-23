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
            'tags': []  # Will track tags user has answered questions for
        }
        
        users_table.put_item(Item=new_user)
        return new_user
        
    except Exception as e:
        print(f"❌ Error in get_or_create_user: {str(e)}")
        raise

def update_user_stats(user_id: str, question_id: str, answer: bool, correct_answer: bool, question_tags: list) -> Dict[str, Any]:
    """
    Update user statistics based on their answer.
    
    Args:
        user_id: UUID string for the user
        question_id: Question ID that was answered
        answer: User's answer (True/False)
        correct_answer: The correct answer
        question_tags: List of tags for the question
        
    Returns:
        Dict containing updated user data
    """
    try:
        current_time = datetime.utcnow().isoformat()
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
        
        # Update tags if new ones are encountered
        if question_tags:
            # Get current user to check existing tags
            user = get_or_create_user(user_id)
            existing_tags = set(user.get('tags', []))
            new_tags = set(question_tags)
            
            # Add any new tags
            updated_tags = list(existing_tags.union(new_tags))
            if updated_tags != list(existing_tags):
                update_expression += ", tags = :tags"
                expression_values[':tags'] = updated_tags
        
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