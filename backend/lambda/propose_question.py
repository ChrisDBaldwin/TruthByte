import json
from backend.logic.propose_question_logic import propose_question_logic

def lambda_handler(event, context):
    """
    AWS Lambda handler for proposing new questions.
    
    The function expects an event from API Gateway with a JSON body containing
    the question data. The body should include:
    - question: The question text
    - answers: List of possible answers
    - correct_answer: Index of the correct answer
    - tags: List of category tags
    
    API Gateway Integration:
    - Request body is passed in event['body'] as a JSON string
    - Response must include statusCode and body
    - CORS headers are required for browser access
    
    Returns:
        API Gateway response with:
        - statusCode: 200 for success, 400 for invalid input, 500 for errors
        - body: JSON string containing success status and question data or error
    """
    try:
        # Parse the request body from API Gateway event
        # API Gateway wraps the body in a "body" field as a string
        body = json.loads(event["body"]) if "body" in event else event
        
        # Submit question to DynamoDB
        response = propose_question_logic(body)
        
        # Return success response
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"  # Required for CORS
            },
            "body": json.dumps({
                "success": True,
                "data": response
            })
        }
    except Exception as e:
        # Return error response
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"  # Required for CORS
            },
            "body": json.dumps({
                "success": False,
                "error": str(e)
            })
        } 