# TruthByte Single Lambda Deployment Script
#
# Quickly deploy a single Lambda function without going through full backend deployment
#
# Usage: .\deploy-single-lambda.ps1 -Environment dev -FunctionName fetch-questions

param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$FunctionName,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

# Validate environment
if ($Environment -notin @("dev", "prod")) {
    Write-Error "Environment must be either 'dev' or 'prod'"
    exit 1
}

# Function mappings
$functions = @{
    "fetch-questions" = "../../backend/lambda/fetch_questions.py"
    "submit-answers" = "../../backend/lambda/submit_answers.py"
    "propose-question" = "../../backend/lambda/propose_question.py"
    "get-token" = "../../backend/lambda/get_token.py"
    "auth-ping" = "../../backend/lambda/auth_ping.py"
    "get-user" = "../../backend/lambda/get_user.py"
    "get-categories" = "../../backend/lambda/get_categories.py"
    "get-user-submissions" = "../../backend/lambda/get_user_submissions.py"
    "approve-question" = "../../backend/lambda/approve_question.py"
    "fetch-daily-questions" = "../../backend/lambda/fetch_daily_questions.py"
    "submit-daily-answers" = "../../backend/lambda/submit_daily_answers.py"
}

if (-not $functions.ContainsKey($FunctionName)) {
    Write-Error "Unknown function: $FunctionName. Available functions: $($functions.Keys -join ', ')"
    exit 1
}

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Get the artifacts bucket name from CloudFormation output
Write-Host "Getting artifacts bucket name..."
$artifactBucket = aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-backend-s3" --query 'Stacks[0].Outputs[?OutputKey==`ArtifactsBucketName`].OutputValue' --output text

if (-not $artifactBucket -or $artifactBucket -eq "None") {
    Write-Error "Could not find artifacts bucket. Make sure the backend S3 stack is deployed first."
    exit 1
}

Write-Host "Using artifacts bucket: $artifactBucket"

# Clean up previous artifacts for this function
$deployDir = "../artifacts/lambda"
if (Test-Path $deployDir) {
    Write-Host "Cleaning up previous Lambda artifacts..."
    Remove-Item $deployDir -Recurse -Force
}

# Create deployment directory
New-Item -ItemType Directory -Force -Path $deployDir

# Package the specific function
$funcPath = $functions[$FunctionName]

Write-Host "Packaging $FunctionName..."

# Create temporary directory for packaging
$tempDir = Join-Path $deployDir $FunctionName
New-Item -ItemType Directory -Force -Path $tempDir

# Copy function code
Write-Host "Copying $funcPath to $tempDir"
if (!(Test-Path $funcPath)) {
    Write-Error "Function file not found: $funcPath"
    exit 1
}
Copy-Item $funcPath $tempDir

# Copy shared auth utilities if needed
$authFunctions = @("get-token", "auth-ping", "fetch-questions", "submit-answers", "propose-question", "get-user", "get-categories", "get-user-submissions", "approve-question", "fetch-daily-questions", "submit-daily-answers")
if ($FunctionName -in $authFunctions) {
    Write-Host "Copying shared auth utilities..."
    Copy-Item "../../backend/shared/*" $tempDir -Recurse -Force
}

# Install dependencies
Write-Host "Installing dependencies to $tempDir"
& py -m pip install -r "../../backend/requirements.txt" -t $tempDir
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install dependencies for $FunctionName"
    exit 1
}

# Create deployment package
$zipFile = Join-Path $deployDir "$FunctionName.zip"

# Try 7-Zip for faster compression, fallback to PowerShell if not available
$sevenZipPath = Get-Command "7z.exe" -ErrorAction SilentlyContinue
if ($sevenZipPath) {
    Write-Host "Using 7-Zip for fast compression..."
    & 7z.exe a -tzip "$zipFile" "$tempDir\*" -mx1 > $null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "7-Zip compression failed for $FunctionName"
        exit 1
    }
} else {
    Write-Host "7-Zip not found, using PowerShell compression (slower)..."
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipFile -Force
}

# Upload to S3
Write-Host "Uploading $FunctionName to S3..."
aws s3 cp $zipFile "s3://$artifactBucket/$FunctionName.zip"

# Update Lambda function code directly
$lambdaFunctionName = "$Environment-truthbyte-$FunctionName"
Write-Host "Updating Lambda function code for $lambdaFunctionName..."

$functionExists = aws lambda get-function --function-name $lambdaFunctionName --query 'Configuration.FunctionName' --output text 2>$null
if ($functionExists -and $functionExists -ne "None") {
    aws lambda update-function-code `
        --function-name $lambdaFunctionName `
        --s3-bucket $artifactBucket `
        --s3-key "$FunctionName.zip"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully updated $lambdaFunctionName"
    } else {
        Write-Error "Failed to update Lambda function code"
        exit 1
    }
} else {
    Write-Error "Lambda function $lambdaFunctionName does not exist. Deploy the full backend first."
    exit 1
}

# Cleanup
Remove-Item $tempDir -Recurse -Force
Remove-Item $zipFile -Force

Write-Host "🎉 Single Lambda deployment completed successfully!"
Write-Host "Function: $lambdaFunctionName"
Write-Host "The function should be available immediately." 