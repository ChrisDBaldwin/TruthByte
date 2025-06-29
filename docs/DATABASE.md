# TruthByte Database Documentation

Complete reference for TruthByte's DynamoDB database architecture, schema, and data management patterns.

## Architecture Overview

TruthByte uses a **hybrid query approach** with fallback mechanisms:

```
Primary Strategy    →    Fallback Strategy
Category Index     →    Filtered Table Scan
(when available)   →    (with pagination)
```

### Key Benefits
- **🚀 Flexible Querying**: Multiple query strategies for reliability
- **⚡ Optimized Performance**: Sub-second for indexed queries, 1-2s for scans
- **💰 Cost Management**: Balanced approach between scans and indexes
- **📈 Fault Tolerance**: Automatic fallback if tables unavailable

## Query Patterns

### Primary Strategy (Category Index)
```python
try:
    # Try using category index
    response = categories_table.query(
        KeyConditionExpression=Key('category').eq(category),
        FilterExpression=Attr('difficulty').eq(difficulty) if difficulty else None
    )
    items = response['Items']
except Exception:
    # Fall back to scan strategy
    items = fallback_scan_strategy()
```

### Fallback Strategy (Table Scan)
```python
def fallback_scan_strategy():
    scan_params = {
        'FilterExpression': Attr('categories').contains(category),
        'Limit': num_questions * 50
    }
    
    items = []
    scan_count = 0
    
    while len(items) < required_count and scan_count < 3:
        response = questions_table.scan(**scan_params)
        items.extend(response.get('Items', []))
        
        if 'LastEvaluatedKey' not in response:
            break
            
        scan_params['ExclusiveStartKey'] = response['LastEvaluatedKey']
        scan_count += 1
    
    return items
```

### Performance Characteristics

1. Category Index Query:
- Response Time: 100-500ms
- Cost: Low (uses index)
- Availability: Depends on table status

2. Fallback Table Scan:
- Response Time: 1-2 seconds
- Cost: Higher (full table scan)
- Availability: Always available
- Pagination: Up to 3 scan operations

## Table Schemas

### 1. Questions Table
**Table Name**: `{environment}-truthbyte-questions`

```
Partition Key: id (String)
Billing: Pay-per-request
```

**Attributes:**
```json
{
  "id": "q001",                         // Unique question identifier
  "question": "string",                 // The question text
  "title": "string",                    // Question title/summary  
  "passage": "string",                  // Context passage
  "answer": true,                       // Canonical true/false answer
  "categories": ["science", "general"], // Primary categories (list)
  "difficulty": 3,                      // Difficulty rating 1-5
  "tags": ["science", "general"]        // Legacy field for backwards compatibility
}
```

**Query Patterns:**
1. Direct ID Lookup:
```python
response = questions_table.get_item(Key={'id': question_id})
```

2. Category-based Query (with scan):
```python
scan_params = {
    'FilterExpression': Attr('categories').contains(category),
    'Limit': num_questions * 50
}
response = questions_table.scan(**scan_params)
```

3. Batch Operations:
```python
response = questions_table.batch_get_item(
    RequestItems={
        'questions_table': {
            'Keys': [{'id': qid} for qid in question_ids]
        }
    }
)
```

### 2. Question-Categories Table
**Table Name**: `{environment}-truthbyte-question-categories`

```
Partition Key: category (String)
Sort Key: question_id (String) 
Billing: Pay-per-request
```

**Attributes:**
```json
{
  "category": "science",          // Category name
  "question_id": "q001",          // Question identifier
  "difficulty": 3                 // Question difficulty (for filtering)
}
```

**Query Patterns:**
1. Category Lookup:
```python
response = categories_table.query(
    KeyConditionExpression=Key('category').eq(category),
    FilterExpression=Attr('difficulty').eq(difficulty) if difficulty else None
)
```

2. Fallback (if table unavailable):
```python
# Fall back to questions table scan
response = questions_table.scan(
    FilterExpression=Attr('categories').contains(category)
)
```

### Error Handling

1. Table Not Available:
```python
try:
    categories_table = dynamodb.Table(categories_table_name)
    categories_table.table_status  # Test if table exists
    USE_CATEGORIES_TABLE = True
except Exception:
    USE_CATEGORIES_TABLE = False
    # Fall back to questions table scan
```

2. Scan Pagination:
```python
items = []
scan_count = 0
while len(items) < required_count and scan_count < 3:
    response = table.scan(**scan_params)
    items.extend(response.get('Items', []))
    
    if 'LastEvaluatedKey' not in response:
        break
        
    scan_params['ExclusiveStartKey'] = response['LastEvaluatedKey']
    scan_count += 1
```

## Performance Optimization

### Query Optimization

1. Minimize Table Scans:
```python
if USE_CATEGORIES_TABLE:
    # Use efficient category-based query
    response = categories_table.query(...)
else:
    # Fall back to filtered scan
    response = questions_table.scan(...)
```

2. Batch Operations:
```python
# Prefer batch operations over multiple single operations
batch_response = dynamodb.batch_get_item(
    RequestItems={
        'questions_table': {
            'Keys': [{'id': qid} for qid in question_ids]
        }
    }
)
```

3. Pagination Control:
```python
# Limit initial scan size
scan_params = {
    'Limit': num_questions * 50,  # Higher limit for filtering
    'FilterExpression': Attr('categories').contains(category)
}
```

### Cost Optimization

1. Selective Scanning:
```python
# Only scan when necessary
if category == 'general':
    scan_params = {'Limit': num_questions * 10}  # Lower limit for general
else:
    scan_params = {
        'FilterExpression': Attr('categories').contains(category),
        'Limit': num_questions * 50  # Higher limit for filtering
    }
```

2. Caching Strategy:
```python
# Cache category counts
category_counts = {}
def get_category_count(category):
    if category not in category_counts:
        response = categories_table.get_item(
            Key={'name': category}
        )
        category_counts[category] = response['Item']['count']
    return category_counts[category]
```

## Monitoring and Debugging

### CloudWatch Metrics

Monitor these metrics:
- ProvisionedReadCapacityUnits
- ConsumedReadCapacityUnits
- SuccessfulRequestLatency
- ThrottledRequests

### Debug Logging

Enable detailed logging:
```python
import boto3
import logging

# Enable boto3 debug logging
boto3.set_stream_logger('botocore', logging.DEBUG)

# Log query parameters
print(f"Query params: {query_params}")
print(f"Requested {num_questions} questions for category: {category}")

# Log results
print(f"Retrieved {len(items)} items for category: {category}")
if items:
    print(f"Sample item structure: {items[0]}")
```

## Migration and Maintenance

### Table Creation

```bash
aws dynamodb create-table \
    --table-name dev-truthbyte-questions \
    --attribute-definitions \
        AttributeName=id,AttributeType=S \
    --key-schema \
        AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
```

### Data Migration

1. Export data:
```python
def export_table(table_name):
    table = dynamodb.Table(table_name)
    response = table.scan()
    with open(f'{table_name}_backup.json', 'w') as f:
        json.dump(response['Items'], f)
```

2. Import data:
```python
def import_table(table_name, items):
    table = dynamodb.Table(table_name)
    with table.batch_writer() as batch:
        for item in items:
            batch.put_item(Item=item)
```

## Security Considerations

### Access Control

1. IAM Policies:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:GetItem",
                "dynamodb:BatchGetItem"
            ],
            "Resource": [
                "arn:aws:dynamodb:*:*:table/dev-truthbyte-*"
            ]
        }
    ]
}
```

2. Encryption:
- Enable encryption at rest
- Use AWS KMS for key management
- Enable CloudTrail logging

### Best Practices

1. Data Validation:
- Use Pydantic models
- Validate input parameters
- Sanitize user input

2. Error Handling:
- Implement retries
- Log errors
- Provide meaningful error messages

3. Monitoring:
- Set up CloudWatch alarms
- Monitor capacity usage
- Track error rates

## Table Schemas

### 3. Categories Table
**Table Name**: `{environment}-truthbyte-categories`

```
Partition Key: name (String)
Billing: Pay-per-request
```

**Attributes:**
```json
{
  "name": "science",              // Category name
  "count": 75,                    // Total questions in category
  "display_name": "Science"       // Human-readable name
}
```

**Usage Pattern:**
- **Category Listing**: Get all available categories with counts
- **Category Management**: Update counts and metadata
- **UI Population**: Provide category selection interface data

### 4. Answers Table
**Table Name**: `{environment}-truthbyte-answers`

```
Partition Key: user_id (String)
Sort Key: question_id (String)
Billing: Pay-per-request
```

**Attributes:**
```json
{
  "user_id": "demo-session-123",   // User session identifier
  "question_id": "q001",           // Question answered
  "answer": true,                  // User's answer
  "timestamp": 1710000000,         // Unix timestamp
  "response_time_ms": 2500         // Time to answer (optional)
}
```

**Usage Pattern:**
- **User History**: Query all answers by user_id
- **Question Stats**: Query all answers for specific question
- **Trust Scoring**: Calculate user reliability

### 5. Sessions Table
**Table Name**: `{environment}-truthbyte-sessions`

```
Partition Key: session_id (String)
Global Secondary Index: ip-hash-index
  - Partition Key: ip_hash (String)
Billing: Pay-per-request
```

**Attributes:**
```json
{
  "session_id": "demo-session-123", // Unique session identifier
  "ip_hash": "sha256hash",           // Hashed IP address
  "created_at": 1710000000,          // Session creation timestamp
  "trust_score": 0.85                // Calculated user trust score
}
```

**Usage Pattern:**
- **Session Lookup**: Get session by session_id
- **IP Tracking**: Query sessions by hashed IP (GSI)
- **Abuse Prevention**: Track IP-based patterns

### 6. Submitted Questions Table
**Table Name**: `{environment}-truthbyte-submitted-questions`

```
Partition Key: id (String)
Billing: Pay-per-request
```

**Attributes:**
```json
{
  "id": "sub_123456789",           // Unique submission identifier
  "question": "string",            // Submitted question text
  "title": "string",               // Question title
  "passage": "string",             // Context passage
  "suggested_answer": true,        // Suggested answer
  "tags": ["science"],             // Suggested tags
  "submitter_id": "demo-session",  // Who submitted
  "status": "pending",             // pending/approved/rejected
  "created_at": 1710000000         // Submission timestamp
}
```

**Usage Pattern:**
- **Moderation Queue**: List pending submissions
- **Approval Workflow**: Update status and promote to main table
- **User Tracking**: Query submissions by submitter

### 7. Users Table (NEW - Daily Mode)
**Table Name**: `{environment}-truthbyte-users`

The user table stores user profiles and progress information.

```json
{
    "user_id": "uuid-string",                            // Primary key
    "trust_score": 42,                                   // User's trust score
    "created_at": "2024-01-15T12:34:56.789Z",           // Account creation timestamp
    "last_active": "2024-01-15T12:34:56.789Z",          // Last activity timestamp
    "daily_progress": {                                  // Daily challenge progress by date
        "2024-01-15": {
            "answers": [
                {
                    "question_id": "q001",
                    "answer": true,
                    "is_correct": true,
                    "timestamp": 1234567890
                }
            ],
            "completed_at": "2024-01-15T12:34:56.789Z"
        }
    },
    "current_daily_streak": 5,                           // Current daily challenge streak
    "best_daily_streak": 10                             // Best daily challenge streak achieved
}
```

Note: Statistics like total questions answered, correct answers, and total daily games can be calculated from the answers table and daily progress data.

**Usage Pattern:**
- **User Profile**: Get complete user data including daily progress
- **Streak Calculation**: Determine current and best streaks
- **Daily Progress**: Track completion status for specific dates
- **Historical Performance**: Analyze user's daily challenge history

## Query Patterns

### Efficient Question Fetching

```python
# 1. Query category index for question IDs
category_response = question_categories_table.query(
    KeyConditionExpression=Key('category').eq('science'),
    FilterExpression=Attr('difficulty').eq(3) if difficulty else None
)
question_ids = [item['question_id'] for item in category_response['Items']]

# 2. Random sampling (client-side)
import random
selected_ids = random.sample(question_ids, min(count, len(question_ids)))

# 3. Batch get full question data
batch_response = dynamodb.batch_get_item(
    RequestItems={
        'questions_table': {
            'Keys': [{'id': qid} for qid in selected_ids]
        }
    }
)
```

### Answer Submission

```python
# Store user answer
answers_table.put_item(
    Item={
        'user_id': user_id,
        'question_id': question_id,
        'answer': answer,
        'timestamp': int(time.time()),
        'response_time_ms': response_time
    }
)

# Calculate trust score
user_answers = answers_table.query(
    KeyConditionExpression=Key('user_id').eq(user_id)
)
# Trust scoring logic...
```

### Daily Mode Queries (NEW)

```python
# Get deterministic daily questions
def get_daily_questions(date_str):
    # 1. Get all questions with difficulty filter
    response = questions_table.scan(
        FilterExpression=Attr('difficulty').between(1, 4),
        Limit=500
    )
    all_questions = response['Items']
    
    # 2. Deterministic selection using date-based seed
    import hashlib
    import random
    
    seed = int.from_bytes(
        hashlib.sha256(f"truthbyte-daily-{date_str}".encode()).digest()[:8], 
        byteorder='big'
    )
    rng = random.Random(seed)
    selected_questions = rng.sample(all_questions, 10)
    
    return selected_questions

# Submit daily answers with score calculation
def submit_daily_answers(user_id, answers, date_str):
    # 1. Verify questions and calculate score
    question_ids = [answer['question_id'] for answer in answers]
    questions = batch_get_questions(question_ids)
    
    correct_count = sum(
        1 for answer in answers 
        if answer['answer'] == questions[answer['question_id']]['answer']
    )
    
    score_percentage = (correct_count / len(answers)) * 100
    rank = calculate_rank(score_percentage)  # S, A, B, C, D
    
    # 2. Update user's daily progress
    users_table.update_item(
        Key={'user_id': user_id},
        UpdateExpression="""
            SET daily_progress.#date = :progress,
                current_daily_streak = :new_streak,
                best_daily_streak = if_not_exists(best_daily_streak, :zero),
                total_daily_games = total_daily_games + :one
        """,
        ExpressionAttributeNames={'#date': date_str},
        ExpressionAttributeValues={
            ':progress': {
                'completed': True,
                'score': Decimal(str(score_percentage)),
                'rank': rank,
                'correct_count': correct_count,
                'total_questions': len(answers),
                'answers': answers,
                'completed_at': int(time.time())
            },
            ':new_streak': calculate_new_streak(user_id, score_percentage >= 70),
            ':zero': 0,
            ':one': 1
        }
    )

# Calculate user's current streak
def calculate_user_streak(user_id):
    user_data = users_table.get_item(Key={'user_id': user_id})['Item']
    daily_progress = user_data.get('daily_progress', {})
    
    current_streak = 0
    dates = sorted(daily_progress.keys(), reverse=True)
    
    for date_str in dates:
        day_data = daily_progress[date_str]
        if day_data.get('completed') and day_data.get('score', 0) >= 70:
            current_streak += 1
        else:
            break
    
    return {
        'current_streak': current_streak,
        'best_streak': user_data.get('best_daily_streak', 0),
        'streak_eligible': True
    }
```

## Data Management

### Adding New Questions

1. **Question Upload**: Add to questions table with categories and difficulty
2. **Category Indexing**: Add entries to question-categories table for each category
3. **Category Counts**: Update category metadata in categories table
4. **Default Tag**: Always include "general" tag for universal queries

```python
# Add question
questions_table.put_item(Item=question_data)

# Add tag mappings
for tag in question_data['tags']:
    question_tags_table.put_item(Item={
        'tag': tag,
        'question_id': question_data['id']
    })
```

### Batch Operations

Use DynamoDB batch operations for efficiency:

```python
# Batch write questions
with questions_table.batch_writer() as batch:
    for question in questions:
        batch.put_item(Item=question)

# Batch write tag mappings  
with question_tags_table.batch_writer() as batch:
    for question in questions:
        for tag in question['tags']:
            batch.put_item(Item={
                'tag': tag,
                'question_id': question['id']
            })
```

## Environment Configuration

### Table Naming Convention
```
{environment}-truthbyte-{table_type}

Examples:
- dev-truthbyte-questions
- prod-truthbyte-questions
- dev-truthbyte-question-tags
```

### CloudFormation Integration
Tables are created via CloudFormation templates in `deploy/infra/dynamodb.yaml`:

```yaml
QuestionsTable:
  Type: AWS::DynamoDB::Table
  Properties:
    TableName: !Sub ${Environment}-truthbyte-questions
    BillingMode: PAY_PER_REQUEST
    AttributeDefinitions:
      - AttributeName: id
        AttributeType: S
    KeySchema:
      - AttributeName: id
        KeyType: HASH
```

## Performance Optimization

### Best Practices
1. **Avoid Scans**: Always use Query or GetItem operations
2. **Batch Operations**: Use batch reads/writes when possible
3. **Client-side Randomization**: Randomize results in application code
4. **Pay-per-request**: Use for unpredictable workloads

### Monitoring
- **CloudWatch Metrics**: Monitor read/write capacity and throttling
- **Lambda Logs**: Track query performance in CloudWatch logs
- **Cost Tracking**: Monitor DynamoDB costs per environment

## Data Migration

### Upload Script Usage
```bash
# Upload questions to development
python scripts/upload_questions.py \
  --environment dev \
  --file data/dev_with_ids.jsonl

# Upload to production
python scripts/upload_questions.py \
  --environment prod \
  --file data/dev_with_ids.jsonl \
  --region us-west-2
```

### Data Format
Questions should be in JSONL format:
```json
{"id": "q001", "question": "text", "title": "title", "passage": "passage", "answer": true, "tags": ["general", "science"]}
{"id": "q002", "question": "text", "title": "title", "passage": "passage", "answer": false, "tags": ["general", "history"]}
```

## Backup and Recovery

### Point-in-Time Recovery
All tables have point-in-time recovery enabled through CloudFormation.

### Cross-Region Replication
Not currently implemented but can be added via DynamoDB Global Tables.

### Data Export
Use DynamoDB export to S3 for large-scale backups:
```bash
aws dynamodb export-table-to-point-in-time \
  --table-arn arn:aws:dynamodb:region:account:table/dev-truthbyte-questions \
  --s3-bucket backup-bucket \
  --export-format DYNAMODB_JSON
```

## Troubleshooting

### Common Issues
1. **"Table not found"**: Check environment prefix in table names
2. **Empty results**: Verify tag exists in question-tags table
3. **Throttling**: Consider switching to provisioned capacity
4. **High costs**: Check for accidental table scans

### Debug Queries
```python
# Check if tag exists
response = question_tags_table.query(
    KeyConditionExpression=Key('tag').eq('science'),
    Limit=1
)
print(f"Tag 'science' has {response['Count']} questions")

# List all available tags
response = question_tags_table.scan(
    ProjectionExpression='tag'
)
tags = set(item['tag'] for item in response['Items'])
print(f"Available tags: {tags}")
```

---

**Last Updated**: Current as of latest database schema  
**Version**: 1.0.0 