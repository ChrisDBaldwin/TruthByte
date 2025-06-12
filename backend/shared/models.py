from pydantic import BaseModel

class AnswerInput(BaseModel):
    user_id: str
    question_id: str
    answer: bool
    timestamp: int 