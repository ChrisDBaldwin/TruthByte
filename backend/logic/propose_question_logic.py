import boto3
import uuid
from typing import Dict, Any
from shared.db import get_dynamodb_table

def propose_question_logic(input_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Submit a new question to DynamoDB.
    
    DynamoDB Operations:
    - put_item: Used to insert a new question
        - Generates a unique question_id using UUID
        - Validates required fields
        - Uses conditional expression to prevent duplicates
    
    Args:
        input_data: Dictionary containing question data:
            - question: str (required)
            - answers: List[str] (required)
            - correct_answer: int (required)
            - tags: List[str] (required)
    
    Returns:
        Dict containing the submitted question with its generated ID
    """
    # Get DynamoDB table resource
    table = get_dynamodb_table("truthbyte-submitted-questions")
    
    # Validate required fields
    required_fields = {"question", "answers", "correct_answer", "tags"}
    if not all(field in input_data for field in required_fields):
        raise ValueError("Missing required fields: question, answers, correct_answer, tags")
    
    # Generate a unique question ID
    question_id = f"q_{uuid.uuid4().hex[:8]}"
    
    # Prepare the item for DynamoDB
    item = {
        "id": question_id,
        "question": input_data["question"],
        "answers": input_data["answers"],
        "correct_answer": input_data["correct_answer"],
        "tags": input_data["tags"],
        "status": "pending"  # Questions start as pending until approved
    }
    
    # Use put_item with condition expression to prevent duplicates
    # This is a safety check, though unlikely with UUID
    table.put_item(
        Item=item,
        ConditionExpression="attribute_not_exists(id)"  # Ensure ID doesn't exist
    )
    
    return item 