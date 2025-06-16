#!/bin/bash

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

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --bucket-name)
            BUCKET_NAME="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --certificate-id)
            CERTIFICATE_ID="$2"
            shift 2
            ;;
        --help)
            echo "TruthByte Frontend Deployment Script"
            echo ""
            echo "Usage: $0 --bucket-name <bucket-name> [--region <aws-region>] [--certificate-id <cert-id>]"
            echo ""
            echo "This script will:"
            echo "1. Build the Zig WebAssembly frontend"
            echo "2. Deploy S3 bucket with OAI"
            echo "3. Deploy CloudFront distribution"
            echo "4. Upload files to S3"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$BUCKET_NAME" ]; then
    echo "Usage: $0 --bucket-name <bucket-name> [--region <aws-region>]"
    echo "Use --help for detailed information"
    exit 1
fi

# Set default region if not provided
REGION=${REGION:-"us-east-1"}
export AWS_DEFAULT_REGION=$REGION

# Validate EMSDK environment variable
if [ -z "$EMSDK" ]; then
    echo "Error: EMSDK environment variable is required for WebAssembly build"
    echo "Please install Emscripten SDK and set EMSDK environment variable"
    echo "See: https://emscripten.org/docs/getting_started/downloads.html"
    exit 1
fi

# Check if zig is available
if ! command -v zig &> /dev/null; then
    echo "Error: Zig compiler not found. Please install Zig and add it to PATH"
    exit 1
fi

echo "Building frontend for WebAssembly..."

# Navigate to frontend directory
pushd "../../frontend" > /dev/null

# Clean previous build
if [ -d "zig-out" ]; then
    rm -rf "zig-out"
fi

# Build for WebAssembly
echo "Compiling to WebAssembly..."
if ! zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseFast; then
    echo "Error: Frontend build failed"
    popd > /dev/null
    exit 1
fi

echo "Frontend build completed successfully"

# Create deployment directory
DEPLOY_DIR="../deploy/frontend"
mkdir -p "$DEPLOY_DIR"

# Copy built files
echo "Preparing deployment files..."

# Check build output location (could be bin or htmlout depending on raylib-zig version)
if [ -f "zig-out/htmlout/game.html" ]; then
    BUILD_DIR="zig-out/htmlout"
elif [ -f "zig-out/bin/game.html" ]; then
    BUILD_DIR="zig-out/bin"
else
    echo "Error: Could not find build output. Expected game.html in zig-out/bin or zig-out/htmlout"
    popd > /dev/null
    exit 1
fi

echo "Found build output in $BUILD_DIR"

# Copy main HTML file
cp "$BUILD_DIR/game.html" "$DEPLOY_DIR/index.html"

# Copy WebAssembly and JavaScript files
cp "$BUILD_DIR/game.wasm" "$DEPLOY_DIR/index.wasm"
cp "$BUILD_DIR/game.js" "$DEPLOY_DIR/index.js"

# Copy any additional assets
if [ -d "res" ]; then
    cp -r "res" "$DEPLOY_DIR/"
fi

echo "Deployment files prepared in $DEPLOY_DIR"

popd > /dev/null

# Deploy S3 bucket infrastructure
echo "Deploying S3 bucket infrastructure..."

aws cloudformation deploy \
    --template-file "../infra/frontend-s3.yaml" \
    --stack-name "truthbyte-frontend-s3" \
    --parameter-overrides BucketName="$BUCKET_NAME"

if [ $? -ne 0 ]; then
    echo "Error: Failed to deploy S3 bucket infrastructure"
    exit 1
fi

# Get OAI ID from S3 stack for CloudFront
echo "Getting CloudFront OAI ID..."
OAI_ID=$(aws cloudformation describe-stacks --stack-name "truthbyte-frontend-s3" --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontOAIId`].OutputValue' --output text)

if [ -z "$OAI_ID" ]; then
    echo "Error: Could not retrieve CloudFront OAI ID from S3 stack"
    exit 1
fi

echo "CloudFront OAI ID: $OAI_ID"

# Deploy CloudFront distribution
echo "Deploying CloudFront distribution..."

if [ -n "$CERTIFICATE_ID" ]; then
    echo "Using SSL certificate ID: $CERTIFICATE_ID"
    aws cloudformation deploy \
        --template-file "../infra/cloudfront.yaml" \
        --stack-name "truthbyte-frontend-cloudfront" \
        --parameter-overrides BucketName="$BUCKET_NAME" OAIId="$OAI_ID" AcmCertificateId="$CERTIFICATE_ID"
else
    echo "No SSL certificate ID provided, please provide one to enable HTTPS"
    exit 1
fi

if [ $? -ne 0 ]; then
    echo "Error: Failed to deploy CloudFront distribution"
    exit 1
fi

# Upload files to S3
echo "Uploading files to S3 bucket: $BUCKET_NAME"

pushd "deploy/frontend" > /dev/null

# Upload HTML files with proper content type
aws s3 cp "index.html" "s3://$BUCKET_NAME/" --content-type "text/html"

# Upload WebAssembly files with proper content type
aws s3 cp "index.wasm" "s3://$BUCKET_NAME/" --content-type "application/wasm"

# Upload JavaScript files with proper content type
aws s3 cp "index.js" "s3://$BUCKET_NAME/" --content-type "application/javascript"

# Upload any additional assets
if [ -d "res" ]; then
    aws s3 cp "res" "s3://$BUCKET_NAME/res/" --recursive
fi

echo "Files uploaded successfully"

popd > /dev/null

# Get the URLs
S3_WEBSITE_URL=$(aws cloudformation describe-stacks --stack-name "truthbyte-frontend-s3" --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' --output text)
CLOUDFRONT_URL=$(aws cloudformation describe-stacks --stack-name "truthbyte-frontend-cloudfront" --query 'Stacks[0].Outputs[?OutputKey==`DistributionDomainName`].OutputValue' --output text)

echo "Frontend deployment complete!"
echo "S3 Website URL: $S3_WEBSITE_URL"
echo "CloudFront URL: https://$CLOUDFRONT_URL"
echo ""
echo "Note: CloudFront distribution may take 10-15 minutes to fully deploy."
echo "Use the CloudFront URL for production access with HTTPS and better performance." 