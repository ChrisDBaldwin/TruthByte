#!/usr/bin/env python3
"""
Upload questions from JSONL file to DynamoDB.

Usage:
    python upload_questions.py --environment dev --file data/dev_with_ids.jsonl
"""

import json
import argparse
import boto3
from botocore.exceptions import ClientError
from typing import Dict, List, Any
import time

def load_jsonl(file_path: str) -> List[Dict[str, Any]]:
    """Load questions from JSONL file."""
    questions = []
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                questions.append(json.loads(line.strip()))
    return questions

def format_question_for_dynamodb(question: Dict[str, Any]) -> Dict[str, Any]:
    """Format question data for DynamoDB storage."""
    tags = question.get('tags', [])
    # Ensure every question has a 'general' tag for efficient querying
    if 'general' not in tags:
        tags = tags + ['general']
    
    return {
        'id': question['id'],
        'question': question['question'],
        'title': question.get('title', ''),
        'passage': question.get('passage', ''),
        'answer': question['answer'],  # Keep as boolean
        'tags': tags
    }

def upload_questions_batch(dynamodb, table_name: str, questions: List[Dict[str, Any]]) -> None:
    """Upload questions to DynamoDB using batch operations."""
    table = dynamodb.Table(table_name)
    
    # DynamoDB batch_writer handles batching automatically (max 25 items per batch)
    with table.batch_writer() as batch:
        for question in questions:
            formatted_question = format_question_for_dynamodb(question)
            batch.put_item(Item=formatted_question)
            print(f"Uploaded question: {formatted_question['id']}")

def upload_question_tags(dynamodb, tags_table_name: str, questions: List[Dict[str, Any]]) -> None:
    """Upload question-tag relationships to separate tags table."""
    tags_table = dynamodb.Table(tags_table_name)
    
    with tags_table.batch_writer() as batch:
        for question in questions:
            question_id = question['id']
            tags = question.get('tags', [])
            
            for tag in tags:
                batch.put_item(Item={
                    'tag': tag,
                    'question_id': question_id
                })
                print(f"Uploaded tag mapping: {tag} -> {question_id}")

def main():
    parser = argparse.ArgumentParser(description='Upload questions to DynamoDB')
    parser.add_argument('--environment', required=True, choices=['dev', 'prod'],
                      help='Environment to upload to (dev|prod)')
    parser.add_argument('--file', required=True,
                      help='Path to JSONL file containing questions')
    parser.add_argument('--region', default='us-east-1',
                      help='AWS region (default: us-east-1)')
    
    args = parser.parse_args()
    
    # Initialize DynamoDB
    dynamodb = boto3.resource('dynamodb', region_name=args.region)
    
    # Table names based on environment
    questions_table_name = f"{args.environment}-truthbyte-questions"
    tags_table_name = f"{args.environment}-truthbyte-question-tags"
    
    print(f"Loading questions from {args.file}...")
    questions = load_jsonl(args.file)
    print(f"Loaded {len(questions)} questions")
    
    # Check if tables exist
    try:
        questions_table = dynamodb.Table(questions_table_name)
        questions_table.load()
        print(f"✓ Questions table exists: {questions_table_name}")
    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceNotFoundException':
            print(f"❌ Questions table not found: {questions_table_name}")
            print("Please deploy the DynamoDB infrastructure first:")
            print(f"  ./deploy-backend.sh --environment {args.environment}")
            return 1
        else:
            raise
    
    try:
        tags_table = dynamodb.Table(tags_table_name)
        tags_table.load()
        print(f"✓ Tags table exists: {tags_table_name}")
        use_tags_table = True
    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceNotFoundException':
            print(f"⚠️  Tags table not found: {tags_table_name}")
            print("Using simplified approach (tags stored as array in questions table)")
            use_tags_table = False
        else:
            raise
    
    # Upload questions
    print(f"\nUploading {len(questions)} questions to {questions_table_name}...")
    start_time = time.time()
    
    try:
        upload_questions_batch(dynamodb, questions_table_name, questions)
        
        if use_tags_table:
            print(f"\nUploading tag mappings to {tags_table_name}...")
            upload_question_tags(dynamodb, tags_table_name, questions)
        
        end_time = time.time()
        print(f"\n✅ Upload completed successfully in {end_time - start_time:.2f} seconds!")
        print(f"Uploaded {len(questions)} questions")
        
        # Calculate total tag mappings if using tags table
        if use_tags_table:
            total_tag_mappings = sum(len(q.get('tags', [])) for q in questions)
            print(f"Uploaded {total_tag_mappings} tag mappings")
            
    except Exception as e:
        print(f"❌ Upload failed: {str(e)}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit(main()) 