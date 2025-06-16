#!/bin/bash

# TruthByte Master Deployment Script
#
# This script can deploy backend, frontend, or both components of TruthByte
#
# Required Environment Variables:
# - AWS_ACCESS_KEY_ID: AWS access key for deployment
# - AWS_SECRET_ACCESS_KEY: AWS secret key for deployment
# - AWS_DEFAULT_REGION: AWS region (defaults to us-east-1 if not provided)
# - EMSDK: Path to Emscripten SDK (required for frontend WebAssembly build)
#
# Command Line Arguments:
# - --component: What to deploy (backend|frontend|all) [default: all]
# - --environment: Deployment environment (dev|prod) [required for backend]
# - --artifact-bucket: S3 bucket name for Lambda artifacts [required for backend]
# - --frontend-bucket: S3 bucket name for frontend hosting [required for frontend]
# - --region: (optional) AWS region to deploy to

# Default values
REGION="us-east-1"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --component)
            COMPONENT="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --artifact-bucket)
            ARTIFACT_BUCKET="$2"
            shift 2
            ;;
        --bucket)
            BUCKET="$2"
            shift 2
            ;;
        --certificate-id)
            CERTIFICATE_ID="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --help)
            echo "TruthByte Master Deployment Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --component <backend|frontend|all>  What to deploy (required)"
            echo "  --environment <dev|prod>            Environment for backend deployment"
            echo "  --artifact-bucket <name>            S3 bucket for Lambda artifacts"
            echo "  --bucket <name>                     S3 bucket for frontend hosting"
            echo "  --certificate-id <id>               ACM certificate ID for HTTPS (optional)"
            echo "  --region <region>                   AWS region (default: us-east-1)"
            echo "  --help                              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --component backend --environment dev --artifact-bucket my-lambda-bucket"
            echo "  $0 --component frontend --bucket my-website.com --certificate-id 12345678-1234-1234-1234-123456789012"
            echo "  $0 --component all --environment prod --artifact-bucket my-lambda-bucket --bucket my-website.com --certificate-id 12345678-1234-1234-1234-123456789012"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate component parameter
if [ -z "$COMPONENT" ]; then
    echo "Error: --component parameter is required"
    echo ""
    echo "Usage: $0 --component <backend|frontend|all> [OPTIONS]"
    echo ""
    echo "Use --help for detailed usage information"
    exit 1
fi

if [[ "$COMPONENT" != "backend" && "$COMPONENT" != "frontend" && "$COMPONENT" != "all" ]]; then
    echo "Error: Component must be 'backend', 'frontend', or 'all'"
    exit 1
fi

# Set AWS region
export AWS_DEFAULT_REGION=$REGION

# Function to deploy backend
deploy_backend() {
    echo "=== Deploying Backend ==="
    
    if [ -z "$ENVIRONMENT" ] || [ -z "$ARTIFACT_BUCKET" ]; then
        echo "Error: Backend deployment requires --environment and --artifact-bucket"
        exit 1
    fi
    
    if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
        echo "Error: Environment must be either 'dev' or 'prod'"
        exit 1
    fi
    
    echo "Deploying backend to $ENVIRONMENT environment..."
    ./deploy-backend.sh --environment "$ENVIRONMENT" --artifact-bucket "$ARTIFACT_BUCKET" --region "$REGION"
    
    if [ $? -ne 0 ]; then
        echo "Error: Backend deployment failed"
        exit 1
    fi
    
    echo "Backend deployment completed successfully"
}

# Function to deploy frontend
deploy_frontend() {
    echo "=== Deploying Frontend ==="
    
    if [ -z "$BUCKET" ]; then
        echo "Error: Frontend deployment requires --bucket"
        exit 1
    fi
    
    echo "Deploying frontend to S3 bucket: $BUCKET"
    if [ -n "$CERTIFICATE_ID" ]; then
        echo "Using SSL certificate ID: $CERTIFICATE_ID"
        ./deploy-frontend.sh --bucket-name "$BUCKET" --region "$REGION" --certificate-id "$CERTIFICATE_ID"
    else
        echo "No SSL certificate ID provided, please provide one to enable HTTPS"
        exit 1
    fi
    
    if [ $? -ne 0 ]; then
        echo "Error: Frontend deployment failed"
        exit 1
    fi
    
    echo "Frontend deployment completed successfully"
}

# Main deployment logic
case $COMPONENT in
    backend)
        deploy_backend
        ;;
    frontend)
        deploy_frontend
        ;;
    all)
        deploy_backend
        echo ""
        deploy_frontend
        ;;
esac

echo ""
echo "=== Deployment Summary ==="
echo "Component(s) deployed: $COMPONENT"
echo "Region: $REGION"

if [[ "$COMPONENT" == "backend" || "$COMPONENT" == "all" ]]; then
    echo "Environment: $ENVIRONMENT"
    API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name "$ENVIRONMENT-truthbyte-api" --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' --output text)
    echo "API Endpoint: $API_ENDPOINT"
fi

if [[ "$COMPONENT" == "frontend" || "$COMPONENT" == "all" ]]; then
    echo "Frontend Bucket: $BUCKET"
    S3_WEBSITE_URL=$(aws cloudformation describe-stacks --stack-name "truthbyte-frontend-s3" --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' --output text)
    CLOUDFRONT_URL=$(aws cloudformation describe-stacks --stack-name "truthbyte-frontend-cloudfront" --query 'Stacks[0].Outputs[?OutputKey==`DistributionDomainName`].OutputValue' --output text)
    echo "S3 Website URL: $S3_WEBSITE_URL"
    echo "CloudFront URL: https://$CLOUDFRONT_URL"
fi

echo ""
echo "Deployment completed successfully!" 