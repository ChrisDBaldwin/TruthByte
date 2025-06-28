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
        
        user = {
            'user_id': user_id,
            'trust_score': Decimal('0'),
            'created_at': current_time,
            'last_active': current_time,
            'daily_progress': {},
            'current_daily_streak': Decimal('0'),
            'best_daily_streak': Decimal('0')
        }
        
        users_table.put_item(Item=user)
        return user
        
    except Exception as e:
        print(f"❌ Error in get_or_create_user: {str(e)}")
        raise

def update_user_stats(user_id: str, trust_delta: float) -> None:
    """
    Update user statistics after answering questions.
    
    Args:
        user_id: UUID string for the user
        trust_delta: Change in trust score
    """
    try:
        current_time = datetime.utcnow().isoformat()
        
        # Update user record
        users_table.update_item(
            Key={'user_id': user_id},
            UpdateExpression="""
                SET last_active = :last_active,
                    trust_score = if_not_exists(trust_score, :zero) + :trust_delta
            """,
            ExpressionAttributeValues={
                ':last_active': current_time,
                ':trust_delta': Decimal(str(trust_delta)),
                ':zero': Decimal('0')
            }
        )
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
    Custom JSON encoder for handling Decimal types from DynamoDB.
    """
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj) 