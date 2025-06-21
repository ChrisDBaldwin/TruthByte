# scripts/

This directory contains utility scripts for preprocessing, analyzing, and uploading data:

## Data Processing Scripts

- `add_id_and_tags.py`: Adds UUIDs and tag metadata to raw question data
- `analyze_data.py`: Aggregates and summarizes question dataset  
- `review_keywords.py`: Aids in tag curation based on keyword frequency

## Production Upload Script

- `upload_questions.py`: **Production-ready script** for uploading questions to DynamoDB

### Upload Script Features

- **Tag-Based Architecture**: Automatically adds `general` tag to enable efficient querying
- **Dual-Table Upload**: Populates both questions table and tag mapping table
- **Batch Operations**: Uses DynamoDB batch operations for optimal performance
- **Smart Detection**: Automatically detects table schema and adapts strategy
- **Progress Tracking**: Real-time progress reporting with error handling
- **Environment Support**: Works with both dev and prod environments

### Usage

```bash
# Upload to development environment
python scripts/upload_questions.py --environment dev --file data/dev_with_ids.jsonl

# Upload to production environment  
python scripts/upload_questions.py --environment prod --file data/dev_with_ids.jsonl

# Specify custom AWS region
python scripts/upload_questions.py --environment dev --file data/dev_with_ids.jsonl --region us-west-2
```

### Architecture Benefits

The upload script implements a **scan-free architecture**:

- ✅ **No Table Scans**: All queries use efficient tag-based indexing
- ✅ **Sub-second Response**: Fast, predictable query performance
- ✅ **Cost Efficient**: Predictable, low-cost DynamoDB operations
- ✅ **Highly Scalable**: Performance doesn't degrade with dataset size

These scripts expect inputs from `/data` and support both file processing and cloud deployment workflows.
