import json
from backend.logic.fetch_questions_logic import fetch_questions_logic

def lambda_handler(event, context):
    """
    AWS Lambda handler for fetching questions from DynamoDB.
    
    The function expects an event from API Gateway with optional query parameters:
    - num_questions: Number of questions to fetch (default: 7, max: 20)
    - tag: Category tag to filter questions
    
    API Gateway Integration:
    - Query parameters are passed in event['queryStringParameters']
    - Response must include statusCode and body
    - CORS headers are required for browser access
    
    Returns:
        API Gateway response with:
        - statusCode: 200 for success, 404 for no questions, 500 for errors
        - headers: Content-Type and CORS headers
        - body: JSON string containing questions or error message
    """
    try:
        # Pass the entire event object to the logic
        # The logic layer handles DynamoDB interactions and response formatting
        return fetch_questions_logic(event)
        
    except Exception as e:
        # Return a proper error response with CORS headers
        # API Gateway requires specific response format
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"  # Required for CORS
            },
            "body": json.dumps({
                "error": f"Unexpected error in lambda handler: {str(e)}"
            })
        } 