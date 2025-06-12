from shared.db import get_dynamodb_table

def submit_answer_logic(input_data):
    table = get_dynamodb_table()
    item = {
        "user_id": input_data["user_id"],
        "question_id": input_data["question_id"],
        "answer": input_data["answer"],
        "timestamp": input_data["timestamp"],
    }
    table.put_item(Item=item)
    return item 