import json
from logic.propose_question_logic import propose_question_logic

def lambda_handler(event, context):
    try:
        body = json.loads(event["body"]) if "body" in event else event
        response = propose_question_logic(body)
        return {
            "statusCode": 200,
            "body": json.dumps({"success": True, "data": response})
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"success": False, "error": str(e)})
        } 