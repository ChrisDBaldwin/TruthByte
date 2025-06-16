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

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("backend", "frontend", "all")]
    [string]$Component,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$ArtifactBucket,
    
    [Parameter(Mandatory=$false)]
    [string]$Bucket,

    [Parameter(Mandatory=$true)]
    [string]$CertificateId,

    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1",
    
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
    Write-Host "  -ArtifactBucket <name>             S3 bucket for Lambda artifacts"
    Write-Host "  -Bucket <name>                     S3 bucket for frontend hosting"
    Write-Host "  -CertificateId <id>                ACM certificate ID for HTTPS"
    Write-Host "  -Region <region>                   AWS region (default: us-east-1)"
    Write-Host "  -Help                              Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\deploy.ps1 -Component backend -Environment dev -ArtifactBucket my-lambda-bucket"
    Write-Host "  .\deploy.ps1 -Component frontend -Bucket my-website.com -CertificateId 12345678-1234-1234-1234-123456789012"
    Write-Host "  .\deploy.ps1 -Component all -Environment prod -ArtifactBucket my-lambda-bucket -Bucket my-website.com -CertificateId 12345678-1234-1234-1234-123456789012"
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
    
    if (-not $Environment -or -not $ArtifactBucket) {
        Write-Error "Backend deployment requires -Environment and -ArtifactBucket parameters"
        exit 1
    }
    
    Write-Host "Deploying backend to $Environment environment..."
    
    $result = & ".\deploy-backend.ps1" -Environment $Environment -ArtifactBucket $ArtifactBucket -Region $Region
    
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
    
    Write-Host "Deploying frontend to S3 bucket: $Bucket"
    
    if ($CertificateId) {
        Write-Host "Using SSL certificate ID: $CertificateId"
        $result = & ".\deploy-frontend.ps1" -BucketName $Bucket -Region $Region -CertificateId $CertificateId
    } else {
        Write-Error "No SSL certificate ID provided, please provide one to enable HTTPS"
        exit 1
    }
    
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