#!/bin/bash

# TruthByte Deployment Script
#
# Required Environment Variables:
# - AWS_ACCESS_KEY_ID: AWS access key for deployment
# - AWS_SECRET_ACCESS_KEY: AWS secret key for deployment
# - AWS_DEFAULT_REGION: AWS region (defaults to us-east-1 if not provided)
#
# Required Command Line Arguments:
# - --environment: Deployment environment (dev|prod)
# - --artifact-bucket: S3 bucket name for Lambda artifacts
# - --region: (optional) AWS region to deploy to

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --artifact-bucket)
            ARTIFACT_BUCKET="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$ENVIRONMENT" ] || [ -z "$ARTIFACT_BUCKET" ]; then
    echo "Usage: $0 --environment <dev|prod> --artifact-bucket <bucket-name> [--region <aws-region>]"
    exit 1
fi

# Set default region if not provided
REGION=${REGION:-"us-east-1"}
export AWS_DEFAULT_REGION=$REGION

# Validate environment
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo "Environment must be either 'dev' or 'prod'"
    exit 1
fi

# Create deployment directory
DEPLOY_DIR="deploy/lambda"
mkdir -p "$DEPLOY_DIR"

# Package Lambda functions
FUNCTIONS=(
    "fetch-questions:../backend/lambda/fetch_questions.py"
    "submit-answers:../backend/lambda/submit_answers.py"
    "propose-question:../backend/lambda/propose_question.py"
)   

for func in "${FUNCTIONS[@]}"; do
    IFS=':' read -r name path <<< "$func"
    echo "Packaging $name..."
    
    # Create temporary directory for packaging
    TEMP_DIR="$DEPLOY_DIR/$name"
    mkdir -p "$TEMP_DIR"
    
    # Copy function code and dependencies
    cp "$path" "$TEMP_DIR"
    cp -r "../backend/logic" "$TEMP_DIR"
    cp -r "../backend/shared" "$TEMP_DIR"
    cp "../backend/requirements.txt" "$TEMP_DIR"
    
    # Install dependencies
    pushd "$TEMP_DIR" > /dev/null
    pip install -r requirements.txt -t .
    rm requirements.txt
    
    # Create deployment package
    ZIP_FILE="$DEPLOY_DIR/$name.zip"
    zip -r "$ZIP_FILE" .
    
    # Upload to S3
    echo "Uploading $name to S3..."
    aws s3 cp "$ZIP_FILE" "s3://$ARTIFACT_BUCKET/$name.zip"
    
    # Cleanup
    popd > /dev/null
    rm -rf "$TEMP_DIR"
done

# Deploy infrastructure
echo "Deploying infrastructure..."

# Deploy DynamoDB tables
aws cloudformation deploy \
    --template-file ../infra/dynamodb.yaml \
    --stack-name "$ENVIRONMENT-truthbyte-dynamodb" \
    --parameter-overrides Environment="$ENVIRONMENT"

# Deploy Lambda functions
aws cloudformation deploy \
    --template-file ../infra/lambdas.yaml \
    --stack-name "$ENVIRONMENT-truthbyte-lambdas" \
    --parameter-overrides Environment="$ENVIRONMENT" ArtifactBucket="$ARTIFACT_BUCKET" \
    --capabilities CAPABILITY_NAMED_IAM

# Deploy API Gateway
aws cloudformation deploy \
    --template-file ../infra/api.yaml \
    --stack-name "$ENVIRONMENT-truthbyte-api" \
    --parameter-overrides Environment="$ENVIRONMENT"

echo "Deployment complete!"
echo "API Endpoint: $(aws cloudformation describe-stacks --stack-name "$ENVIRONMENT-truthbyte-api" --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' --output text)" 