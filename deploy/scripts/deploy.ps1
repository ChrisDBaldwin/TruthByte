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

param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$ArtifactBucket,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

# Validate environment
if ($Environment -notin @("dev", "prod")) {
    Write-Error "Environment must be either 'dev' or 'prod'"
    exit 1
}

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Create deployment directory
$deployDir = "deploy/lambda"
New-Item -ItemType Directory -Force -Path $deployDir

# Package Lambda functions
$functions = @(
    @{name="fetch-questions"; path="../backend/lambda/fetch_questions.py"},
    @{name="submit-answers"; path="../backend/lambda/submit_answers.py"},
    @{name="propose-question"; path="../backend/lambda/propose_question.py"}
)

foreach ($func in $functions) {
    Write-Host "Packaging $($func.name)..."
    
    # Create temporary directory for packaging
    $tempDir = Join-Path $deployDir $func.name
    New-Item -ItemType Directory -Force -Path $tempDir
    
    # Copy function code and dependencies
    Copy-Item $func.path $tempDir
    Copy-Item "../backend/logic" $tempDir -Recurse
    Copy-Item "../backend/shared" $tempDir -Recurse
    Copy-Item "../backend/requirements.txt" $tempDir
    
    # Install dependencies
    Push-Location $tempDir
    pip install -r requirements.txt -t .
    Remove-Item requirements.txt
    
    # Create deployment package
    $zipFile = Join-Path $deployDir "$($func.name).zip"
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipFile -Force
    
    # Upload to S3
    Write-Host "Uploading $($func.name) to S3..."
    aws s3 cp $zipFile "s3://$ArtifactBucket/$($func.name).zip"
    
    # Cleanup
    Remove-Item $tempDir -Recurse -Force
    Pop-Location
}

# Deploy infrastructure
Write-Host "Deploying infrastructure..."

# Deploy DynamoDB tables
aws cloudformation deploy `
    --template-file ../infra/dynamodb.yaml `
    --stack-name "$Environment-truthbyte-dynamodb" `
    --parameter-overrides Environment=$Environment

# Deploy Lambda functions
aws cloudformation deploy `
    --template-file ../infra/lambdas.yaml `
    --stack-name "$Environment-truthbyte-lambdas" `
    --parameter-overrides Environment=$Environment ArtifactBucket=$ArtifactBucket `
    --capabilities CAPABILITY_NAMED_IAM

# Deploy API Gateway
aws cloudformation deploy `
    --template-file ../infra/api.yaml `
    --stack-name "$Environment-truthbyte-api" `
    --parameter-overrides Environment=$Environment

Write-Host "Deployment complete!"
Write-Host "API Endpoint: $(aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-api" --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' --output text)" 