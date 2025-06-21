import jwt
import os
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