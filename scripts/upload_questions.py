#!/usr/bin/env python3
"""
Upload questions from JSONL file to DynamoDB.

Usage:
    python upload_questions.py --environment dev --file ../data/curated_questions.jsonl
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
    # Handle both new schema (single 'category') and old schema ('categories' array)
    if 'category' in question:
        # New schema: single category string
        category = question['category']
        categories = [category] if category else ['general']
    else:
        # Old schema: support both 'categories' and 'tags' arrays
        categories = question.get('categories') or question.get('tags', [])
        # Ensure every question has a 'general' category for efficient querying
        if 'general' not in categories:
            categories = categories + ['general']
    
    # Get difficulty rating (default to 3 - medium)
    difficulty = question.get('difficulty', 3)
    try:
        difficulty = int(difficulty)
        if difficulty < 1 or difficulty > 5:
            difficulty = 3
    except (ValueError, TypeError):
        difficulty = 3
    
    return {
        'id': question['id'],
        'question': question['question'],
        'title': question.get('title', ''),
        'passage': question.get('passage', ''),
        'answer': question['answer'],  # Keep as boolean
        'categories': categories,  # Always store as array for compatibility
        'difficulty': difficulty
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

def upload_question_categories(dynamodb, categories_table_name: str, questions: List[Dict[str, Any]]) -> None:
    """Upload question-category relationships to separate categories table."""
    categories_table = dynamodb.Table(categories_table_name)
    
    with categories_table.batch_writer() as batch:
        for question in questions:
            question_id = question['id']
            
            # Handle both new schema (single 'category') and old schema ('categories' array)
            if 'category' in question:
                # New schema: single category string
                categories = [question['category']] if question['category'] else ['general']
            else:
                # Old schema: categories array
                categories = question.get('categories', [])
            
            for category in categories:
                batch.put_item(Item={
                    'category': category,
                    'question_id': question_id
                })
                print(f"Uploaded category mapping: {category} -> {question_id}")

def upload_category_metadata(dynamodb, metadata_table_name: str, questions: List[Dict[str, Any]]) -> None:
    """Upload category metadata to categories table."""
    metadata_table = dynamodb.Table(metadata_table_name)
    
    # Collect category statistics
    category_stats = {}
    
    for question in questions:
        # Handle both new schema (single 'category') and old schema ('categories' array)  
        if 'category' in question:
            categories = [question['category']] if question['category'] else ['general']
        else:
            categories = question.get('categories', [])
            
        difficulty = question.get('difficulty', 3)
        
        for category in categories:
            if category not in category_stats:
                category_stats[category] = {
                    'count': 0,
                    'difficulties': [],
                    'sample_questions': []
                }
            
            category_stats[category]['count'] += 1
            category_stats[category]['difficulties'].append(difficulty)
            
            # Keep a few sample questions
            if len(category_stats[category]['sample_questions']) < 3:
                category_stats[category]['sample_questions'].append(question.get('question', ''))
    
    # Category descriptions
    category_descriptions = {
        'general': 'General knowledge and miscellaneous topics',
        'entertainment': 'Movies, TV shows, music, and celebrity trivia',
        'sports': 'Sports, athletes, teams, and Olympic games',
        'geography': 'Countries, cities, capitals, and world locations',
        'science': 'Science, nature, animals, and technology',
        'history': 'Historical events, figures, and periods',
        'food': 'Food, cooking, restaurants, and culinary culture',
        'business': 'Companies, brands, and business topics'
    }
    
    # Upload category metadata
    with metadata_table.batch_writer() as batch:
        for category, stats in category_stats.items():
            avg_difficulty = sum(stats['difficulties']) / len(stats['difficulties']) if stats['difficulties'] else 3
            avg_difficulty_int = round(avg_difficulty)  # Convert to integer
            
            batch.put_item(Item={
                'category_id': category,
                'name': category.replace('_', ' ').title(),
                'description': category_descriptions.get(category, f'{category.title()} related questions'),
                'question_count': stats['count'],
                'avg_difficulty': avg_difficulty_int,
                'sample_questions': stats['sample_questions']
            })
            print(f"Uploaded category metadata: {category} ({stats['count']} questions, avg difficulty: {avg_difficulty_int})")

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
    categories_table_name = f"{args.environment}-truthbyte-question-categories"
    metadata_table_name = f"{args.environment}-truthbyte-categories"
    
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
        categories_table = dynamodb.Table(categories_table_name)
        categories_table.load()
        print(f"✓ Categories table exists: {categories_table_name}")
        use_categories_table = True
    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceNotFoundException':
            print(f"⚠️  Categories table not found: {categories_table_name}")
            print("Using simplified approach (categories stored as array in questions table)")
            use_categories_table = False
        else:
            raise
    
    try:
        metadata_table = dynamodb.Table(metadata_table_name)
        metadata_table.load()
        print(f"✓ Category metadata table exists: {metadata_table_name}")
        use_metadata_table = True
    except ClientError as e:
        if e.response['Error']['Code'] == 'ResourceNotFoundException':
            print(f"⚠️  Category metadata table not found: {metadata_table_name}")
            print("Skipping category metadata upload")
            use_metadata_table = False
        else:
            raise
    
    # Upload questions
    print(f"\nUploading {len(questions)} questions to {questions_table_name}...")
    start_time = time.time()
    
    try:
        upload_questions_batch(dynamodb, questions_table_name, questions)
        
        if use_categories_table:
            print(f"\nUploading category mappings to {categories_table_name}...")
            upload_question_categories(dynamodb, categories_table_name, questions)
        
        if use_metadata_table:
            print(f"\nUploading category metadata to {metadata_table_name}...")
            upload_category_metadata(dynamodb, metadata_table_name, questions)
        
        end_time = time.time()
        print(f"\n✅ Upload completed successfully in {end_time - start_time:.2f} seconds!")
        print(f"Uploaded {len(questions)} questions")
        
        # Calculate total category mappings if using categories table
        if use_categories_table:
            total_category_mappings = sum(len(q.get('categories', [])) for q in questions)
            print(f"Uploaded {total_category_mappings} category mappings")
            
        if use_metadata_table:
            print(f"Uploaded category metadata for available categories")
            
    except Exception as e:
        print(f"❌ Upload failed: {str(e)}")
        return 1
    
    return 0

if __name__ == '__main__':
    exit(main()) 