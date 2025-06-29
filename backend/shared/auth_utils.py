import jwt
import os
import re
import uuid
from datetime import datetime, timedelta
from typing import Dict, Tuple, Optional
from jwt.exceptions import ExpiredSignatureError, InvalidTokenError

# Constants
SECRET = os.environ["JWT_SECRET"]
ALGO = "HS256"
TOKEN_EXPIRY_HOURS = 12
REFRESH_TOKEN_EXPIRY_DAYS = 30

class AuthError(Exception):
    """Base class for authentication errors"""
    def __init__(self, message: str, status_code: int = 401):
        super().__init__(message)
        self.status_code = status_code
        self.message = message

class TokenExpiredError(AuthError):
    """Raised when token has expired"""
    pass

class InvalidTokenFormatError(AuthError):
    """Raised when token format is invalid"""
    pass

class MissingHeaderError(AuthError):
    """Raised when required headers are missing"""
    pass

def create_token_pair(session_id: str) -> Dict[str, str]:
    """
    Create both access and refresh tokens for a session.
    
    Args:
        session_id: Unique session identifier
        
    Returns:
        Dict containing access_token and refresh_token
    """
    access_token = create_access_token(session_id)
    refresh_token = create_refresh_token(session_id)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "Bearer",
        "expires_in": TOKEN_EXPIRY_HOURS * 3600  # Convert to seconds
    }

def create_access_token(session_id: str) -> str:
    """
    Create a short-lived access token.
    
    Args:
        session_id: Session identifier
        
    Returns:
        JWT access token
    """
    payload = {
        "session_id": session_id,
        "exp": datetime.utcnow() + timedelta(hours=TOKEN_EXPIRY_HOURS),
        "type": "access"
    }
    return jwt.encode(payload, SECRET, algorithm=ALGO)

def create_refresh_token(session_id: str) -> str:
    """
    Create a long-lived refresh token.
    
    Args:
        session_id: Session identifier
        
    Returns:
        JWT refresh token
    """
    payload = {
        "session_id": session_id,
        "exp": datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRY_DAYS),
        "type": "refresh"
    }
    return jwt.encode(payload, SECRET, algorithm=ALGO)

def verify_token(token: str, token_type: str = "access") -> dict:
    """
    Verify and decode a JWT token.
    
    Args:
        token: JWT token to verify
        token_type: Expected token type ("access" or "refresh")
        
    Returns:
        Decoded token payload
        
    Raises:
        TokenExpiredError: If token has expired
        InvalidTokenFormatError: If token format is invalid
    """
    try:
        payload = jwt.decode(token, SECRET, algorithms=[ALGO])
        
        # Verify token type
        if payload.get("type") != token_type:
            raise InvalidTokenFormatError(f"Invalid token type. Expected {token_type}")
            
        return payload
        
    except ExpiredSignatureError:
        raise TokenExpiredError("Token has expired")
    except InvalidTokenError as e:
        raise InvalidTokenFormatError(f"Invalid token format: {str(e)}")

def refresh_access_token(refresh_token: str) -> str:
    """
    Create new access token using refresh token.
    
    Args:
        refresh_token: Valid refresh token
        
    Returns:
        New access token
        
    Raises:
        Various AuthError subclasses for different failure cases
    """
    try:
        payload = verify_token(refresh_token, token_type="refresh")
        return create_access_token(payload["session_id"])
    except TokenExpiredError:
        raise TokenExpiredError("Refresh token has expired. Please log in again.")
    except InvalidTokenFormatError as e:
        raise InvalidTokenFormatError(f"Invalid refresh token: {str(e)}")

def extract_user_id(headers: Dict[str, str]) -> str:
    """
    Extract and validate user_id from request headers.
    
    Args:
        headers: Dictionary of request headers
        
    Returns:
        Valid UUID string
        
    Raises:
        MissingHeaderError: If X-User-ID header is missing
        InvalidTokenFormatError: If user_id format is invalid
    """
    user_id = headers.get('X-User-ID') or headers.get('x-user-id')
    
    if not user_id:
        raise MissingHeaderError("Missing X-User-ID header")
    
    if not is_valid_uuid(user_id):
        raise InvalidTokenFormatError("Invalid UUID format for user_id")
    
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

def extract_and_verify_auth(headers: Dict[str, str]) -> Tuple[str, str]:
    """
    Extract and verify authentication information from headers.
    
    Args:
        headers: Request headers
        
    Returns:
        Tuple of (user_id, session_id)
        
    Raises:
        Various AuthError subclasses for different failure cases
    """
    auth_header = headers.get('Authorization') or headers.get('authorization', '')
    
    if not auth_header.startswith('Bearer '):
        raise InvalidTokenFormatError("Missing or invalid Authorization header")
    
    token = auth_header[len("Bearer "):]
    payload = verify_token(token)
    user_id = extract_user_id(headers)
    
    return user_id, payload["session_id"] 