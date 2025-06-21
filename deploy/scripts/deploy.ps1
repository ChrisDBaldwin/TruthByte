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
# - --frontend-bucket: S3 bucket name for frontend hosting [required for frontend]
# - --region: (optional) AWS region to deploy to

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("backend", "frontend", "all")]
    [string]$Component,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod")]
    [string]$Environment,
        
    [Parameter(Mandatory=$false)]
    [string]$Bucket,

    [Parameter(Mandatory=$false)]
    [string]$FrontendCertificateId,

    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
    [Parameter(Mandatory=$false)]
    [string]$ApiCertificateArn,
    
    [Parameter(Mandatory=$false)]
    [string]$JwtSecret,
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

if ($Help) {
    Write-Host "TruthByte Master Deployment Script"
    Write-Host ""
    Write-Host "Usage: .\deploy.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Component <backend|frontend|all>  What to deploy (required)"
    Write-Host "  -Environment <dev|prod>            Environment for backend deployment"
    Write-Host "  -Bucket <name>                     S3 bucket for frontend hosting"
    Write-Host "  -FrontendCertificateId <id>        ACM certificate ID for HTTPS (frontend CloudFront)"
    Write-Host "  -Region <region>                   AWS region (default: us-east-1)"
    Write-Host "  -ApiCertificateArn <arn>           ACM certificate ARN for API custom domain (backend)"
    Write-Host "  -JwtSecret <secret>                JWT secret for token signing (backend)"
    Write-Host "  -Help                              Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\deploy.ps1 -Component backend -Environment dev -ApiCertificateArn 'arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id' -JwtSecret 'your-secret'"
    Write-Host "  .\deploy.ps1 -Component frontend -Bucket my-website.com -FrontendCertificateId 12345678-1234-1234-1234-123456789012"
    Write-Host "  .\deploy.ps1 -Component all -Environment prod -Bucket my-website.com -FrontendCertificateId 12345678-1234-1234-1234-123456789012 -ApiCertificateArn 'arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id' -JwtSecret 'your-secret'"
    exit 0
}

# Validate component parameter
if (-not $Component) {
    Write-Error "The -Component parameter is required"
    Write-Host ""
    Write-Host "Usage: .\deploy.ps1 -Component <backend|frontend|all> [OPTIONS]"
    Write-Host ""
    Write-Host "Use -Help for detailed usage information"
    exit 1
}

# Set AWS region
$env:AWS_DEFAULT_REGION = $Region

# Function to deploy backend
function Deploy-Backend {
    Write-Host "=== Deploying Backend ===" -ForegroundColor Green
    
    if (-not $Environment) {
        Write-Error "Backend deployment requires -Environment parameter"
        exit 1
    }
    
    if (-not $ApiCertificateArn) {
        Write-Error "Backend deployment requires -ApiCertificateArn parameter"
        exit 1
    }
    
    if (-not $JwtSecret) {
        Write-Error "Backend deployment requires -JwtSecret parameter"
        exit 1
    }
    
    Write-Host "Deploying backend to $Environment environment..."
    
    $result = & ".\deploy-backend.ps1" -Environment $Environment -Region $Region -ApiCertificateArn $ApiCertificateArn -JwtSecret $JwtSecret
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Backend deployment failed"
        exit 1
    }
    
    Write-Host "Backend deployment completed successfully" -ForegroundColor Green
}

# Function to deploy frontend
function Deploy-Frontend {
    Write-Host "=== Deploying Frontend ===" -ForegroundColor Green
    
    if (-not $Bucket) {
        Write-Error "Frontend deployment requires -Bucket parameter"
        exit 1
    }
    
    if (-not $FrontendCertificateId) {
        Write-Error "Frontend deployment requires -FrontendCertificateId parameter"
        exit 1
    }
    
    Write-Host "Deploying frontend to S3 bucket: $Bucket"
    Write-Host "Using SSL certificate ID: $FrontendCertificateId"
    
    $result = & ".\deploy-frontend.ps1" -BucketName $Bucket -Region $Region -FrontendCertificateId $FrontendCertificateId
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Frontend deployment failed"
        exit 1
    }
    
    Write-Host "Frontend deployment completed successfully" -ForegroundColor Green
}

# Main deployment logic
switch ($Component) {
    "backend" {
        Deploy-Backend
    }
    "frontend" {
        Deploy-Frontend
    }
    "all" {
        Deploy-Backend
        Write-Host ""
        Deploy-Frontend
    }
}

Write-Host ""
Write-Host "=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host "Component(s) deployed: $Component"
Write-Host "Region: $Region"

if ($Component -eq "backend" -or $Component -eq "all") {
    Write-Host "Environment: $Environment"
    $apiEndpoint = aws cloudformation describe-stacks --stack-name "$Environment-truthbyte-api" --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' --output text
    Write-Host "API Endpoint: $apiEndpoint"
}

if ($Component -eq "frontend" -or $Component -eq "all") {
    Write-Host "Frontend Bucket: $Bucket"
    $s3WebsiteUrl = aws cloudformation describe-stacks --stack-name "truthbyte-frontend-s3" --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' --output text
    $cloudFrontUrl = aws cloudformation describe-stacks --stack-name "truthbyte-frontend-cloudfront" --query 'Stacks[0].Outputs[?OutputKey==`DistributionDomainName`].OutputValue' --output text
    Write-Host "S3 Website URL: $s3WebsiteUrl"
    Write-Host "CloudFront URL: https://$cloudFrontUrl"
}

Write-Host ""
Write-Host "Deployment completed successfully!" -ForegroundColor Green 