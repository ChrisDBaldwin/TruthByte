import json
from backend.logic.fetch_questions_logic import fetch_questions_logic

def lambda_handler(event, context):
    try:
        body = json.loads(event["body"]) if "body" in event else event
        response = fetch_questions_logic(body)
        return {
            "statusCode": 200,
            "body": json.dumps({"success": True, "data": response})
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"success": False, "error": str(e)})
        } 