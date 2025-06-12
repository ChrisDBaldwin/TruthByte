import json
from backend.logic.fetch_questions_logic import fetch_questions_logic

def lambda_handler(event, context):
    """
    Lambda handler for fetching questions.
    
    Query Parameters:
    - num_questions (optional): Number of questions to fetch (default: 7, max: 20)
    - tag (optional): Category tag to filter questions
    
    Returns:
    - JSON response with questions data or error message
    """
    try:
        # Pass the entire event object to the logic
        return fetch_questions_logic(event)
        
    except Exception as e:
        # Return a proper error response with CORS headers
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({
                "error": f"Unexpected error in lambda handler: {str(e)}"
            })
        } 