from shared.db import get_dynamodb_table
from typing import List, Dict, Any
import boto3

def submit_answers_logic(input_data: List[Dict[str, Any]]) -> bool:
    """
    Submit multiple answers to DynamoDB using batch_write_item.
    
    Args:
        input_data: List of answer dictionaries, each containing:
            - user_id: str
            - question_id: str
            - answer: bool
            - timestamp: int
    
    Returns:
        bool: True if all answers were submitted successfully, False otherwise
    """
    # Get DynamoDB table resource using our shared helper
    table = get_dynamodb_table("truthbyte-answers")
    # Create a DynamoDB resource client for batch operations
    dynamodb = boto3.resource('dynamodb')
    
    # Prepare batch write request
    # Each item needs to be wrapped in a PutRequest for batch_write_item
    batch_items = []
    for answer in input_data:
        # Format each answer as a DynamoDB item
        item = {
            "user_id": answer["user_id"],
            "question_id": answer["question_id"],
            "answer": answer["answer"],
            "timestamp": answer["timestamp"],
        }
        # Add to batch with PutRequest wrapper
        batch_items.append({
            'PutRequest': {
                'Item': item
            }
        })
    
    # Use batch_write_item to write multiple items in a single API call
    # This is more efficient than individual put_item calls
    # Note: DynamoDB has a limit of 25 items per batch_write_item call
    response = dynamodb.batch_write_item(
        RequestItems={
            table.name: batch_items
        }
    )
    
    # Check for any unprocessed items
    # If DynamoDB couldn't process all items, they'll be in UnprocessedItems
    # This could happen due to throttling or other temporary issues
    if 'UnprocessedItems' in response and table.name in response['UnprocessedItems']:
        print(f"Unprocessed items: {response['UnprocessedItems'][table.name]}")
        return False
    
    return True 