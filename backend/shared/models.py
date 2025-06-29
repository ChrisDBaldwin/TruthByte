from pydantic import BaseModel, Field, constr, conlist
from typing import List, Optional, Dict
from datetime import datetime
from enum import Enum

class QuestionDifficulty(int, Enum):
    """Enumeration for question difficulty levels"""
    VERY_EASY = 1
    EASY = 2
    MEDIUM = 3
    HARD = 4
    VERY_HARD = 5

class AnswerInput(BaseModel):
    """Model for user answer submission input"""
    user_id: str = Field(..., description="UUID of the user submitting the answer")
    question_id: str = Field(..., description="ID of the question being answered")
    answer: bool = Field(..., description="User's true/false answer")
    timestamp: int = Field(..., description="Unix timestamp of answer submission")
    response_time_ms: Optional[int] = Field(None, description="Time taken to answer in milliseconds")

class Question(BaseModel):
    """Model for question data"""
    id: str = Field(..., description="Unique question identifier")
    question: constr(min_length=10, max_length=200) = Field(..., description="The question text")
    title: Optional[constr(max_length=100)] = Field(None, description="Question title/summary")
    passage: Optional[constr(max_length=500)] = Field(None, description="Context passage")
    answer: bool = Field(..., description="Canonical true/false answer")
    categories: conlist(str, min_items=1, max_items=5) = Field(..., description="Primary categories")
    difficulty: QuestionDifficulty = Field(..., description="Difficulty rating 1-5")
    tags: List[str] = Field(default_factory=list, description="Legacy field for backwards compatibility")

class Category(BaseModel):
    """Model for category metadata"""
    name: str = Field(..., description="Category identifier")
    count: int = Field(..., ge=0, description="Total questions in category")
    display_name: str = Field(..., description="Human-readable category name")

class QuestionCategory(BaseModel):
    """Model for question-category mapping"""
    category: str = Field(..., description="Category name")
    question_id: str = Field(..., description="Question identifier")
    difficulty: QuestionDifficulty = Field(..., description="Question difficulty")

class UserDailyProgress(BaseModel):
    """Model for daily challenge progress"""
    answers: List[Dict] = Field(default_factory=list, description="List of answers for the day")
    completed_at: Optional[datetime] = Field(None, description="Timestamp of completion")
    score: Optional[float] = Field(None, ge=0, le=100, description="Score as percentage")

class User(BaseModel):
    """Model for user profile and progress"""
    user_id: str = Field(..., description="UUID user identifier")
    trust_score: float = Field(default=0.0, ge=0, le=100, description="User's trust score")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="Account creation timestamp")
    last_active: datetime = Field(default_factory=datetime.utcnow, description="Last activity timestamp")
    daily_progress: Dict[str, UserDailyProgress] = Field(
        default_factory=dict,
        description="Daily challenge progress by date"
    )
    current_daily_streak: int = Field(default=0, ge=0, description="Current daily challenge streak")
    best_daily_streak: int = Field(default=0, ge=0, description="Best daily challenge streak achieved")

class Session(BaseModel):
    """Model for user session data"""
    session_id: str = Field(..., description="Unique session identifier")
    ip_hash: str = Field(..., description="Hashed IP address")
    created_at: int = Field(..., description="Session creation timestamp")
    trust_score: float = Field(default=0.0, ge=0, le=1, description="Calculated user trust score")

class SubmittedQuestion(BaseModel):
    """Model for user-submitted questions"""
    id: str = Field(..., description="Unique submission identifier")
    question: constr(min_length=10, max_length=200) = Field(..., description="Submitted question text")
    title: Optional[constr(max_length=100)] = Field(None, description="Question title")
    passage: Optional[constr(max_length=500)] = Field(None, description="Context passage")
    suggested_answer: bool = Field(..., description="Suggested answer")
    tags: conlist(str, min_items=1, max_items=5) = Field(..., description="Suggested tags")
    submitter_id: str = Field(..., description="Who submitted")
    status: str = Field(..., description="pending/approved/rejected")
    created_at: int = Field(..., description="Submission timestamp") 