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

param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipPackaging = $false,
    
    [Parameter(Mandatory=$true)]
    [string]$ApiCertificateArn,
    
    [Parameter(Mandatory=$true)]
    [string]$JwtSecret
)

# Validate environment
if ($Environment -notin @("dev", "prod")) {
    Write-Error "Environment must be either 'dev' or 'prod'"
    exit 1
}

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Deploy backend S3 bucket for artifacts
Write-Host "Deploying backend artifacts S3 bucket..."
aws cloudformation deploy `
    --template-file ../infra/backend-s3.yaml `
    --stack-name "$Environment-truthbyte-backend-s3" `
    --parameter-overrides Environment=$Environment

# Get the artifacts bucket name from CloudFormation output
$artifactBucket = aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-backend-s3" --query 'Stacks[0].Outputs[?OutputKey==`ArtifactsBucketName`].OutputValue' --output text

if (-not $SkipPackaging) {
    # Clean up previous artifacts to avoid conflicts
    $deployDir = "../artifacts/lambda"
    if (Test-Path $deployDir) {
        Write-Host "Cleaning up previous Lambda artifacts..."
        Remove-Item $deployDir -Recurse -Force
    }

    # Create deployment directory
    New-Item -ItemType Directory -Force -Path $deployDir
}

if (-not $SkipPackaging) {
    # Create Lambda venv if it doesn't exist
    $venvPath = "../artifacts/.venv"
    if (!(Test-Path $venvPath)) {
        Write-Host "Creating Lambda virtual environment with Python 3.13..."
        py -m venv $venvPath
        & $venvPath\Scripts\Activate.ps1
    }

    # Package Lambda functions
    $functions = @(
        @{name="fetch-questions"; path="../../backend/lambda/fetch_questions.py"},
        @{name="submit-answers"; path="../../backend/lambda/submit_answers.py"},
        @{name="propose-question"; path="../../backend/lambda/propose_question.py"},
        @{name="get-token"; path="../../backend/lambda/get_token.py"},
        @{name="auth-ping"; path="../../backend/lambda/auth_ping.py"},
        @{name="get-user"; path="../../backend/lambda/get_user.py"}
    )

    foreach ($func in $functions) {
        Write-Host "Packaging $($func.name)..."
        
        # Create temporary directory for packaging
        $tempDir = Join-Path $deployDir $func.name
        New-Item -ItemType Directory -Force -Path $tempDir
        
        # Copy function code and dependencies
        Write-Host "Copying $($func.path) to $tempDir"
        if (!(Test-Path $func.path)) {
            Write-Error "Function file not found: $($func.path)"
            exit 1
        }
        Copy-Item $func.path $tempDir
        
        # Also copy the shared module for auth functions
        if ($func.name -in @("get-token", "auth-ping", "fetch-questions", "submit-answers", "propose-question", "get-user")) {
            Write-Host "Copying shared auth utilities..."
            # Copy shared files directly to temp directory (not as subdirectory)
            Copy-Item "../../backend/shared/*" $tempDir -Recurse -Force
        }
        
        # Install dependencies using Lambda venv
        Write-Host "Installing dependencies to $tempDir"
        & py -m pip install -r "../../backend/requirements.txt" -t $tempDir
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install dependencies for $($func.name)"
            exit 1
        }
        
        # Create deployment package
        $zipFile = Join-Path $deployDir "$($func.name).zip"
        
        # Try 7-Zip for faster compression, fallback to PowerShell if not available
        $sevenZipPath = Get-Command "7z.exe" -ErrorAction SilentlyContinue
        if ($sevenZipPath) {
            Write-Host "Using 7-Zip for fast compression..."
            & 7z.exe a -tzip "$zipFile" "$tempDir\*" -mx1 > $null
            if ($LASTEXITCODE -ne 0) {
                Write-Error "7-Zip compression failed for $($func.name)"
                exit 1
            }
        } else {
            Write-Host "7-Zip not found, using PowerShell compression (slower)..."
            Compress-Archive -Path "$tempDir\*" -DestinationPath $zipFile -Force
        }
        
        # Upload to S3
        Write-Host "Uploading $($func.name) to S3..."
        aws s3 cp $zipFile "s3://$artifactBucket/$($func.name).zip"

        # Update Lambda function code directly (bypass CloudFormation detection issues)
        # Redirect output to null to keep deployment logs clean
        $functionName = "$Environment-truthbyte-$($func.name)"
        Write-Host "Updating Lambda function code for $functionName..."
        aws lambda update-function-code `
            --function-name $functionName `
            --s3-bucket $artifactBucket `
            --s3-key "$($func.name).zip" > $null
        
        # Cleanup
        Remove-Item $tempDir -Recurse -Force
    }
} else {
    Write-Host "Skipping Lambda packaging (using existing S3 artifacts)..."
}

# Deploy backend infrastructure
Write-Host "Deploying backend infrastructure..."

# Deploy DynamoDB tables
Write-Host "Deploying DynamoDB tables..."
aws cloudformation deploy `
    --template-file ../infra/dynamodb.yaml `
    --stack-name "$Environment-truthbyte-dynamodb" `
    --parameter-overrides Environment=$Environment
Write-Host "DynamoDB tables deployed"

# Deploy Lambda functions
Write-Host "Deploying Lambda functions..."
aws cloudformation deploy `
    --template-file ../infra/lambdas.yaml `
    --stack-name "$Environment-truthbyte-lambdas" `
    --parameter-overrides Environment=$Environment ArtifactBucket=$artifactBucket JwtSecret=$JwtSecret `
    --capabilities CAPABILITY_NAMED_IAM 
Write-Host "Lambda functions deployed"

# Get Lambda function ARNs for API Gateway deployment
$fetchFunctionArn = aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-lambdas" --query 'Stacks[0].Outputs[?OutputKey==`FetchQuestionsFunctionArn`].OutputValue' --output text
$submitFunctionArn = aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-lambdas" --query 'Stacks[0].Outputs[?OutputKey==`SubmitAnswerFunctionArn`].OutputValue' --output text
$proposeFunctionArn = aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-lambdas" --query 'Stacks[0].Outputs[?OutputKey==`ProposeQuestionFunctionArn`].OutputValue' --output text
$getTokenFunctionArn = aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-lambdas" --query 'Stacks[0].Outputs[?OutputKey==`GetTokenFunctionArn`].OutputValue' --output text
$authPingFunctionArn = aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-lambdas" --query 'Stacks[0].Outputs[?OutputKey==`AuthPingFunctionArn`].OutputValue' --output text
$getUserFunctionArn = aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-lambdas" --query 'Stacks[0].Outputs[?OutputKey==`GetUserFunctionArn`].OutputValue' --output text

# Deploy API Gateway with custom domain
Write-Host "Deploying API Gateway with custom domain..."
aws cloudformation deploy `
    --template-file ../infra/api.yaml `
    --stack-name "$Environment-truthbyte-api" `
    --parameter-overrides Environment=$Environment FetchQuestionsFunctionArn="$fetchFunctionArn" SubmitAnswerFunctionArn="$submitFunctionArn" ProposeQuestionFunctionArn="$proposeFunctionArn" GetTokenFunctionArn="$getTokenFunctionArn" AuthPingFunctionArn="$authPingFunctionArn" GetUserFunctionArn="$getUserFunctionArn" ApiCertificateArn="$ApiCertificateArn"
Write-Host "API Gateway deployed"
Write-Host "Backend deployment complete!"
Write-Host "API Endpoint: $(aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-api" --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' --output text)"

# Show custom domain info
$distributionDomain = aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-api" --query 'Stacks[0].Outputs[?OutputKey==`DistributionDomainName`].OutputValue' --output text
$customDomainName = aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-api" --query 'Stacks[0].Outputs[?OutputKey==`CustomDomainName`].OutputValue' --output text
Write-Host ""
Write-Host "=== Custom Domain Setup ==="
Write-Host "Custom Domain: https://$customDomainName/$Environment"
Write-Host "IMPORTANT: Create this DNS CNAME record:"
Write-Host "  $customDomainName -> $distributionDomain"
Write-Host "" 