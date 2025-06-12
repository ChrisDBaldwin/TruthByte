import boto3

def get_dynamodb_table():
    dynamodb = boto3.resource("dynamodb")
    return dynamodb.Table("answers") 