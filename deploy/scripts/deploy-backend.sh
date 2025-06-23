#!/bin/bash

# TruthByte Backend Deployment Script
#
# Required Environment Variables:
# - AWS_ACCESS_KEY_ID: AWS access key for deployment
# - AWS_SECRET_ACCESS_KEY: AWS secret key for deployment
# - AWS_DEFAULT_REGION: AWS region (defaults to us-east-1 if not provided)
#
# Required Command Line Arguments:
# - --environment: Deployment environment (dev|prod)
# - --api-certificate-arn: ARN of the SSL certificate for api.truthbyte.voidtalker.com (must be in us-east-1)
# - --jwt-secret: JWT secret key for token signing and verification
# - --region: (optional) AWS region to deploy to

# Parse command line arguments
SKIP_PACKAGING=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --api-certificate-arn)
            API_CERTIFICATE_ARN="$2"
            shift 2
            ;;
        --jwt-secret)
            JWT_SECRET="$2"
            shift 2
            ;;
        --skip-packaging)
            SKIP_PACKAGING=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 --environment <dev|prod> --api-certificate-arn <api-cert-arn> --jwt-secret <jwt-secret> [--region <aws-region>] [--skip-packaging]"
    exit 1
fi

if [ -z "$API_CERTIFICATE_ARN" ]; then
    echo "Error: --api-certificate-arn is required"
    echo "Usage: $0 --environment <dev|prod> --api-certificate-arn <api-cert-arn> --jwt-secret <jwt-secret> [--region <aws-region>] [--skip-packaging]"
    exit 1
fi

if [ -z "$JWT_SECRET" ]; then
    echo "Error: --jwt-secret is required"
    echo "Usage: $0 --environment <dev|prod> --api-certificate-arn <api-cert-arn> --jwt-secret <jwt-secret> [--region <aws-region>] [--skip-packaging]"
    exit 1
fi

# Validate environment
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo "Environment must be either 'dev' or 'prod'"
    exit 1
fi

# Set default region if not provided
REGION=${REGION:-"us-east-1"}
export AWS_DEFAULT_REGION=$REGION

# Deploy backend S3 bucket for artifacts
echo "Deploying backend artifacts S3 bucket..."
aws cloudformation deploy \
    --template-file ../infra/backend-s3.yaml \
    --stack-name "$ENVIRONMENT-truthbyte-backend-s3" \
    --parameter-overrides Environment="$ENVIRONMENT"

# Get the artifacts bucket name from CloudFormation output
ARTIFACT_BUCKET=$(aws cloudformation describe-stacks --stack-name "$ENVIRONMENT-truthbyte-backend-s3" --query 'Stacks[0].Outputs[?OutputKey==`ArtifactsBucketName`].OutputValue' --output text)

if [ "$SKIP_PACKAGING" = false ]; then
    # Clean up previous artifacts to avoid conflicts
    DEPLOY_DIR="../artifacts/lambda"
    if [ -d "$DEPLOY_DIR" ]; then
        echo "Cleaning up previous Lambda artifacts..."
        rm -rf "$DEPLOY_DIR"
    fi

    # Create deployment directory
    mkdir -p "$DEPLOY_DIR"

    # Create Lambda venv if it doesn't exist
    VENV_PATH="../artifacts/.venv"
    if [ ! -d "$VENV_PATH" ]; then
        echo "Creating Lambda virtual environment with Python 3.13..."
        python3 -m venv "$VENV_PATH"
        source "$VENV_PATH/bin/activate"
    fi

    # Package Lambda functions
    FUNCTIONS=(
        "fetch-questions:../../backend/lambda/fetch_questions.py"
        "submit-answers:../../backend/lambda/submit_answers.py"
        "propose-question:../../backend/lambda/propose_question.py"
        "get-token:../../backend/lambda/get_token.py"
        "auth-ping:../../backend/lambda/auth_ping.py"
        "get-user:../../backend/lambda/get_user.py"
    )   

    for func in "${FUNCTIONS[@]}"; do
        IFS=':' read -r name path <<< "$func"
        echo "Packaging $name..."
        
        # Create temporary directory for packaging
        TEMP_DIR="$DEPLOY_DIR/$name"
        mkdir -p "$TEMP_DIR"
        
        # Copy function code and dependencies
        echo "Copying $path to $TEMP_DIR"
        if [ ! -f "$path" ]; then
            echo "Function file not found: $path"
            exit 1
        fi
        cp "$path" "$TEMP_DIR"
        
        # Also copy the shared module for auth functions
        if [[ "$name" == "get-token" || "$name" == "auth-ping" || "$name" == "fetch-questions" || "$name" == "submit-answers" || "$name" == "propose-question" || "$name" == "get-user" ]]; then
            echo "Copying shared auth utilities..."
            cp -r "../../backend/shared" "$TEMP_DIR/"
        fi
        
        # Install dependencies using Lambda venv
        echo "Installing dependencies to $TEMP_DIR"
        python3 -m pip install -r "../../backend/requirements.txt" -t "$TEMP_DIR"
        if [ $? -ne 0 ]; then
            echo "Failed to install dependencies for $name"
            exit 1
        fi
        
        # Create deployment package
        ZIP_FILE="$DEPLOY_DIR/$name.zip"
        pushd "$TEMP_DIR" > /dev/null
        zip -r "../$name.zip" .
        popd > /dev/null
        
        # Upload to S3
        echo "Uploading $name to S3..."
        aws s3 cp "$ZIP_FILE" "s3://$ARTIFACT_BUCKET/$name.zip"

        # Update Lambda function code directly (bypass CloudFormation detection issues)
        # Redirect output to null to keep deployment logs clean
        FUNCTION_NAME="$ENVIRONMENT-truthbyte-$name"
        echo "Updating Lambda function code for $FUNCTION_NAME..."
        aws lambda update-function-code \
            --function-name "$FUNCTION_NAME" \
            --s3-bucket "$ARTIFACT_BUCKET" \
            --s3-key "$name.zip" > /dev/null
        
        # Cleanup
        rm -rf "$TEMP_DIR"
    done
else
    echo "Skipping Lambda packaging (using existing S3 artifacts)..."
fi

# Deploy backend infrastructure
echo "Deploying backend infrastructure..."

# Deploy DynamoDB tables
echo "Deploying DynamoDB tables..."
aws cloudformation deploy \
    --template-file ../infra/dynamodb.yaml \
    --stack-name "$ENVIRONMENT-truthbyte-dynamodb" \
    --parameter-overrides Environment="$ENVIRONMENT"
echo "DynamoDB tables deployed"

# Deploy Lambda functions
echo "Deploying Lambda functions..."
aws cloudformation deploy \
    --template-file ../infra/lambdas.yaml \
    --stack-name "$ENVIRONMENT-truthbyte-lambdas" \
    --parameter-overrides Environment="$ENVIRONMENT" ArtifactBucket="$ARTIFACT_BUCKET" JwtSecret="$JWT_SECRET" \
    --capabilities CAPABILITY_NAMED_IAM
echo "Lambda functions deployed"

# Get Lambda function ARNs for API Gateway deployment
FETCH_FUNCTION_ARN=$(aws cloudformation describe-stacks --stack-name "$ENVIRONMENT-truthbyte-lambdas" --query 'Stacks[0].Outputs[?OutputKey==`FetchQuestionsFunctionArn`].OutputValue' --output text)
SUBMIT_FUNCTION_ARN=$(aws cloudformation describe-stacks --stack-name "$ENVIRONMENT-truthbyte-lambdas" --query 'Stacks[0].Outputs[?OutputKey==`SubmitAnswerFunctionArn`].OutputValue' --output text)
PROPOSE_FUNCTION_ARN=$(aws cloudformation describe-stacks --stack-name "$ENVIRONMENT-truthbyte-lambdas" --query 'Stacks[0].Outputs[?OutputKey==`ProposeQuestionFunctionArn`].OutputValue' --output text)
GET_TOKEN_FUNCTION_ARN=$(aws cloudformation describe-stacks --stack-name "$ENVIRONMENT-truthbyte-lambdas" --query 'Stacks[0].Outputs[?OutputKey==`GetTokenFunctionArn`].OutputValue' --output text)
AUTH_PING_FUNCTION_ARN=$(aws cloudformation describe-stacks --stack-name "$ENVIRONMENT-truthbyte-lambdas" --query 'Stacks[0].Outputs[?OutputKey==`AuthPingFunctionArn`].OutputValue' --output text)
GET_USER_FUNCTION_ARN=$(aws cloudformation describe-stacks --stack-name "$ENVIRONMENT-truthbyte-lambdas" --query 'Stacks[0].Outputs[?OutputKey==`GetUserFunctionArn`].OutputValue' --output text)

# Deploy API Gateway with custom domain
echo "Deploying API Gateway with custom domain..."
aws cloudformation deploy \
    --template-file ../infra/api.yaml \
    --stack-name "$ENVIRONMENT-truthbyte-api" \
    --parameter-overrides \
        Environment="$ENVIRONMENT" \
        FetchQuestionsFunctionArn="$FETCH_FUNCTION_ARN" \
        SubmitAnswerFunctionArn="$SUBMIT_FUNCTION_ARN" \
        ProposeQuestionFunctionArn="$PROPOSE_FUNCTION_ARN" \
        GetTokenFunctionArn="$GET_TOKEN_FUNCTION_ARN" \
        AuthPingFunctionArn="$AUTH_PING_FUNCTION_ARN" \
        GetUserFunctionArn="$GET_USER_FUNCTION_ARN" \
        ApiCertificateArn="$API_CERTIFICATE_ARN"
echo "API Gateway deployed"

echo "Backend deployment complete!"
echo "API Endpoint: $(aws cloudformation describe-stacks --stack-name "$ENVIRONMENT-truthbyte-api" --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' --output text)"

# Show custom domain info
DISTRIBUTION_DOMAIN=$(aws cloudformation describe-stacks --stack-name "$ENVIRONMENT-truthbyte-api" --query 'Stacks[0].Outputs[?OutputKey==`DistributionDomainName`].OutputValue' --output text)
CUSTOM_DOMAIN_NAME=$(aws cloudformation describe-stacks --stack-name "$ENVIRONMENT-truthbyte-api" --query 'Stacks[0].Outputs[?OutputKey==`CustomDomainName`].OutputValue' --output text)
echo ""
echo "=== Custom Domain Setup ==="
echo "Custom Domain: https://$CUSTOM_DOMAIN_NAME/$ENVIRONMENT"
echo "IMPORTANT: Create this DNS CNAME record:"
echo "  $CUSTOM_DOMAIN_NAME -> $DISTRIBUTION_DOMAIN"
echo "" 