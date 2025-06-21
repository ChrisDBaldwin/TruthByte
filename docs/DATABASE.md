# TruthByte Database Documentation

Complete reference for TruthByte's DynamoDB database architecture, schema, and data management patterns.

## Architecture Overview

TruthByte uses a **dual-table design** optimized for tag-based queries without expensive table scans:

```
Questions Table      Question-Tags Table
     ↓                      ↓
  Full Data         ←→   Tag Indexing
(by question ID)      (by tag + question ID)
```

### Key Benefits
- **🚀 No Table Scans**: All queries use efficient indexing
- **⚡ Sub-second Response**: Fast, predictable performance
- **💰 Cost Efficient**: Predictable DynamoDB costs
- **📈 Highly Scalable**: Performance doesn't degrade with size

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
  "id": "q001",                    // Unique question identifier
  "question": "string",            // The question text
  "title": "string",               // Question title/summary  
  "passage": "string",             // Context passage
  "answer": true,                  // Canonical true/false answer
  "tags": ["science", "general"]   // Category tags (list)
}
```

**Usage Pattern:**
- **Batch Read**: Get multiple questions by ID list
- **Single Read**: Get specific question by ID
- **No Scans**: Never scan this table directly

### 2. Question-Tags Table
**Table Name**: `{environment}-truthbyte-question-tags`

```
Partition Key: tag (String)
Sort Key: question_id (String) 
Billing: Pay-per-request
```

**Attributes:**
```json
{
  "tag": "science",               // Category tag
  "question_id": "q001"           // Question identifier
}
```

**Usage Pattern:**
- **Query by Tag**: Get all question IDs for a tag
- **Random Sampling**: Client-side randomization of results
- **High Performance**: O(1) tag lookups

### 3. Answers Table
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

### 4. Sessions Table
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

### 5. Submitted Questions Table
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

## Query Patterns

### Efficient Question Fetching

```python
# 1. Query tag index for question IDs
tag_response = question_tags_table.query(
    KeyConditionExpression=Key('tag').eq('science')
)
question_ids = [item['question_id'] for item in tag_response['Items']]

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

## Data Management

### Adding New Questions

1. **Question Upload**: Add to questions table
2. **Tag Indexing**: Add entries to question-tags table for each tag
3. **Default Tag**: Always include "general" tag for universal queries

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