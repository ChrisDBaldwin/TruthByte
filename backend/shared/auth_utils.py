import jwt
import os
import re
import uuid
from datetime import datetime, timedelta

SECRET = os.environ["JWT_SECRET"]
ALGO = "HS256"

def create_token(session_id: str) -> str:
    """
    Create a JWT token with the given session_id.
    Token expires in 12 hours.
    """
    payload = {
        "session_id": session_id,
        "exp": datetime.utcnow() + timedelta(hours=12),
    }
    return jwt.encode(payload, SECRET, algorithm=ALGO)

def verify_token(token: str) -> dict:
    """
    Verify and decode a JWT token.
    Returns the decoded payload if valid.
    Raises an exception if invalid or expired.
    """
    return jwt.decode(token, SECRET, algorithms=[ALGO])

def extract_user_id(headers: dict) -> str:
    """
    Extract and validate user_id from request headers.
    
    Args:
        headers: Dictionary of request headers
        
    Returns:
        str: Valid UUID string
        
    Raises:
        ValueError: If user_id is missing or invalid
    """
    user_id = headers.get('X-User-ID') or headers.get('x-user-id')
    
    if not user_id:
        raise ValueError("Missing X-User-ID header")
    
    # Validate UUID format
    try:
        uuid.UUID(user_id)
    except ValueError:
        raise ValueError("Invalid UUID format for user_id")
    
    return user_id

def is_valid_uuid(uuid_string: str) -> bool:
    """
    Check if a string is a valid UUID.
    
    Args:
        uuid_string: String to validate
        
    Returns:
        bool: True if valid UUID, False otherwise
    """
    try:
        uuid.UUID(uuid_string)
        return True
    except ValueError:
        return False 