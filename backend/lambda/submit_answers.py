import json
from typing import List, Dict, Any
from backend.logic.submit_answers_logic import submit_answers_logic

def validate_answer(answer: Dict[str, Any]) -> bool:
    """Validate a single answer dictionary."""
    required_fields = {"user_id", "question_id", "answer", "timestamp"}
    return (
        isinstance(answer, dict) and
        all(field in answer for field in required_fields) and
        isinstance(answer["user_id"], str) and
        isinstance(answer["question_id"], str) and
        isinstance(answer["answer"], bool) and
        isinstance(answer["timestamp"], (int, float))
    )

def lambda_handler(event, context):
    """
    AWS Lambda handler for submitting multiple answers.
    
    The function expects an event from API Gateway with a JSON body containing
    a list of answer objects. Each answer must have user_id, question_id,
    answer, and timestamp fields.
    
    Args:
        event: API Gateway event containing the request body
        context: Lambda context object (unused)
    
    Returns:
        API Gateway response with:
        - statusCode: 200 for success, 400 for bad request, 500 for server error
        - body: JSON string containing success status and optional error message
    """
    try:
        # Parse the request body from API Gateway event
        # API Gateway wraps the body in a "body" field as a string
        body = json.loads(event["body"]) if "body" in event else event
        
        # Validate input is a list
        if not isinstance(body, list):
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "success": False,
                    "error": "Input must be a list of answers"
                })
            }
        
        # Validate each answer's structure and types
        if not all(validate_answer(answer) for answer in body):
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "success": False,
                    "error": "Each answer must contain user_id (str), question_id (str), answer (bool), and timestamp (number)"
                })
            }
        
        # Submit answers to DynamoDB
        success = submit_answers_logic(body)
        
        # Return appropriate response based on submission result
        # API Gateway expects statusCode and body in the response
        return {
            "statusCode": 200 if success else 500,
            "body": json.dumps({
                "success": success
            })
        }
    except Exception as e:
        # Handle any unexpected errors
        return {
            "statusCode": 500,
            "body": json.dumps({
                "success": False,
                "error": str(e)
            })
        } 