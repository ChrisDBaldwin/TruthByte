# TruthByte Frontend Deployment Script
#
# Required Environment Variables:
# - AWS_ACCESS_KEY_ID: AWS access key for deployment
# - AWS_SECRET_ACCESS_KEY: AWS secret key for deployment
# - AWS_DEFAULT_REGION: AWS region (defaults to us-east-1 if not provided)
# - EMSDK: Path to Emscripten SDK (required for WebAssembly build)
#
# Required Command Line Arguments:
# - --bucket-name: S3 bucket name for frontend hosting
# - --region: (optional) AWS region to deploy to

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$true)]
    [string]$FrontendCertificateId,  # Certificate ID (not ARN) for CloudFront distribution
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

if ($Help) {
    Write-Host "TruthByte Frontend Deployment Script"
    Write-Host ""
    Write-Host "Usage: .\deploy-frontend.ps1 -BucketName <bucket-name> [-Region <aws-region>] [-FrontendCertificateId <cert-id>]"
    Write-Host ""
    Write-Host "This script will:"
    Write-Host "1. Build the Zig WebAssembly frontend"
    Write-Host "2. Deploy S3 bucket with OAI"
    Write-Host "3. Deploy CloudFront distribution"
    Write-Host "4. Upload files to S3"
    exit 0
}

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Validate EMSDK environment variable
if (-not $env:EMSDK) {
    Write-Error "EMSDK environment variable is required for WebAssembly build"
    Write-Host "Please install Emscripten SDK and set EMSDK environment variable"
    Write-Host "See: https://emscripten.org/docs/getting_started/downloads.html"
    exit 1
}

# Check if zig is available
if (-not (Get-Command "zig" -ErrorAction SilentlyContinue)) {
    Write-Error "Zig compiler not found. Please install Zig and add it to PATH"
    exit 1
}

Write-Host "Building frontend for WebAssembly..."

# Navigate to frontend directory
Push-Location "../../frontend"

try {
    # Clean previous build
    if (Test-Path "zig-out") {
        Remove-Item "zig-out" -Recurse -Force
    }

    # Build for WebAssembly
    Write-Host "Compiling to WebAssembly..."
    $buildResult = & zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseFast 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Frontend build failed:"
        Write-Error $buildResult
        exit 1
    }

    Write-Host "Frontend build completed successfully"

    # Create deployment directory
    $deployDir = "../deploy/artifacts/frontend"
    New-Item -ItemType Directory -Force -Path $deployDir

    # Copy built files
    Write-Host "Preparing deployment files..."
    
    # Check build output location (could be bin or htmlout depending on raylib-zig version)
    if (Test-Path "zig-out/htmlout/index.html") {
        $buildDir = "zig-out/htmlout"
    } elseif (Test-Path "zig-out/bin/index.html") {
        $buildDir = "zig-out/bin"
    } else {
        Write-Error "Could not find build output. Expected game.html in zig-out/bin or zig-out/htmlout"
        exit 1
    }
    
    Write-Host "Found build output in $buildDir"
    
    # Copy main HTML file
    Copy-Item "$buildDir/index.html" "$deployDir/index.html" -Force
    
    # Copy WebAssembly and JavaScript files
    Copy-Item "$buildDir/index.wasm" "$deployDir/index.wasm" -Force
    Copy-Item "$buildDir/index.js" "$deployDir/index.js" -Force
    
    # Copy any additional assets
    if (Test-Path "res") {
        Copy-Item "res" "$deployDir/" -Recurse -Force
    }

    Write-Host "Deployment files prepared in $deployDir"

} finally {
    Pop-Location
}

# Deploy S3 bucket infrastructure
Write-Host "Deploying S3 bucket infrastructure..."

aws cloudformation deploy `
    --template-file "../infra/frontend-s3.yaml" `
    --stack-name "truthbyte-frontend-s3" `
    --parameter-overrides BucketName="$BucketName"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to deploy S3 bucket infrastructure"
    exit 1
}

# Get OAI ID from S3 stack for CloudFront
Write-Host "Getting CloudFront OAI ID..."
$oaiId = aws cloudformation describe-stacks --stack-name "truthbyte-frontend-s3" --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontOAIId`].OutputValue' --output text

if (-not $oaiId) {
    Write-Error "Could not retrieve CloudFront OAI ID from S3 stack"
    exit 1
}

Write-Host "CloudFront OAI ID: $oaiId"

# Deploy CloudFront distribution
Write-Host "Deploying CloudFront distribution..."

if ($FrontendCertificateId) {
    Write-Host "Using SSL certificate ID: $FrontendCertificateId"
    aws cloudformation deploy `
        --template-file "../infra/cloudfront.yaml" `
        --stack-name "truthbyte-frontend-cloudfront" `
        --parameter-overrides BucketName="$BucketName" OAIId="$oaiId" AcmCertificateId="$FrontendCertificateId"
} else {
    Write-Error "No SSL certificate ID provided, please provide one to enable HTTPS"
    exit 1
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to deploy CloudFront distribution"
    exit 1
}

# Upload files to S3
Write-Host "Uploading files to S3 bucket: $BucketName"

Push-Location "../artifacts/frontend"

try {
    # Upload HTML files with proper content type and no cache
    aws s3 cp "index.html" "s3://$BucketName/" --content-type "text/html" --cache-control "no-store, must-revalidate"
    
    # Upload WebAssembly and JavaScript files with short cache
    aws s3 cp "index.wasm" "s3://$BucketName/" --content-type "application/wasm" --cache-control "no-store, must-revalidate"
    aws s3 cp "index.js" "s3://$BucketName/" --content-type "application/javascript" --cache-control "no-store, must-revalidate"
    
    # Upload any additional assets
    if (Test-Path "res") {
        aws s3 cp "res" "s3://$BucketName/res/" --recursive
    }
    
    Write-Host "Files uploaded successfully"

} finally {
    Pop-Location
}

# Get the URLs and distribution ID
$s3WebsiteUrl = aws cloudformation describe-stacks --stack-name "truthbyte-frontend-s3" --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' --output text
$cloudFrontUrl = aws cloudformation describe-stacks --stack-name "truthbyte-frontend-cloudfront" --query 'Stacks[0].Outputs[?OutputKey==`DistributionDomainName`].OutputValue' --output text
$distributionId = aws cloudformation describe-stacks --stack-name "truthbyte-frontend-cloudfront" --query 'Stacks[0].Outputs[?OutputKey==`DistributionId`].OutputValue' --output text

# Invalidate CloudFront cache
Write-Host "Invalidating CloudFront cache..."
aws cloudfront create-invalidation `
  --distribution-id "$distributionId" `
  --paths "/index.html" "/index.js" "/index.wasm"

Write-Host "Frontend deployment complete!"
Write-Host "S3 Website URL: $s3WebsiteUrl"
Write-Host "CloudFront URL: https://$cloudFrontUrl"
Write-Host ""
Write-Host "Note: CloudFront distribution may take 10-15 minutes to fully deploy."
Write-Host "Use the CloudFront URL for production access with HTTPS and better performance." 