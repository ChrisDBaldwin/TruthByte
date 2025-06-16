# TruthByte Deployment Scripts

This directory contains deployment scripts for both the backend and frontend components of TruthByte.

## Structure

```
deploy/
├── scripts/
│   ├── deploy.sh                 # Master deployment script (Bash)
│   ├── deploy.ps1                # Master deployment script (PowerShell)
│   ├── deploy-backend.sh         # Backend-only deployment (Bash)
│   ├── deploy-backend.ps1        # Backend-only deployment (PowerShell)
│   ├── deploy-frontend.sh        # Frontend-only deployment (Bash)
│   └── deploy-frontend.ps1       # Frontend-only deployment (PowerShell)
└── infra/
    ├── dynamodb.yaml             # DynamoDB tables
    ├── lambdas.yaml              # Lambda functions
    ├── api.yaml                  # API Gateway
    ├── frontend-s3.yaml          # S3 bucket for frontend hosting
    └── cloudfront.yaml           # CloudFront distribution
```

## Prerequisites

### Backend Deployment
- AWS CLI configured with appropriate credentials
- Python 3.13+ with pip
- Required AWS permissions for CloudFormation, DynamoDB, Lambda, API Gateway, and S3

### Frontend Deployment
- AWS CLI configured with appropriate credentials
- [Zig compiler](https://ziglang.org/download/) installed and in PATH
- [Emscripten SDK (EMSDK)](https://emscripten.org/docs/getting_started/downloads.html) installed with `EMSDK` environment variable set

## Usage

### Master Deployment Scripts

The master deployment scripts can deploy backend, frontend, or both components.

#### Bash (Linux/macOS/WSL)

```bash
# Deploy everything
./scripts/deploy.sh \
  --component all \
  --environment dev \
  --artifact-bucket my-lambda-artifacts \
  --bucket my-website.com \
  --cloudfront-oai E1234567890ABCD

# Deploy only backend
./scripts/deploy.sh \
  --component backend \
  --environment prod \
  --artifact-bucket my-lambda-artifacts

# Deploy only frontend
./scripts/deploy.sh \
  --component frontend \
  --bucket my-website.com

# Show help
./scripts/deploy.sh --help
```

#### PowerShell (Windows)

```powershell
# Deploy everything
.\scripts\deploy.ps1 `
  -Component all `
  -Environment dev `
  -ArtifactBucket my-lambda-artifacts `
  -Bucket my-website.com

# Deploy only backend
.\scripts\deploy.ps1 `
  -Component backend `
  -Environment prod `
  -ArtifactBucket my-lambda-artifacts

# Deploy only frontend
.\scripts\deploy.ps1 `
  -Component frontend `
  -Bucket my-website.com

# Show help
.\scripts\deploy.ps1 -Help
```

### Individual Component Scripts

You can also use the individual scripts directly:

#### Backend Deployment

```bash
# Bash
./scripts/deploy-backend.sh --environment dev --artifact-bucket my-lambda-artifacts

# PowerShell
.\scripts\deploy-backend.ps1 -Environment dev -ArtifactBucket my-lambda-artifacts
```

#### Frontend Deployment

```bash
# Bash
./scripts/deploy-frontend.sh --bucket-name my-website.com

# PowerShell
.\scripts\deploy-frontend.ps1 -BucketName my-website.com
```

## Parameters

### Master Script Parameters
- `--component` / `-Component`: What to deploy (backend|frontend|all) **[Required]**

### Common Parameters
- `--region` / `-Region`: AWS region (default: us-east-1)

### Backend Parameters
- `--environment` / `-Environment`: Deployment environment (dev|prod) **[Required]**
- `--artifact-bucket` / `-ArtifactBucket`: S3 bucket for Lambda deployment packages **[Required]**

### Frontend Parameters
- `--bucket` / `-Bucket`: S3 bucket name for frontend hosting **[Required]**
- `--certificate-id` / `-CertificateId`: ACM certificate ID for HTTPS **[Required]**

### Individual Script Parameters
Note: Individual scripts use more descriptive parameter names:
- Frontend scripts use `--bucket-name` / `-BucketName` and `--certificate-id` / `-CertificateId`

## Environment Variables

### Required for Backend
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key

### Required for Frontend
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `EMSDK`: Path to Emscripten SDK installation

### Optional
- `AWS_DEFAULT_REGION`: AWS region (can be overridden by --region parameter)

## CloudFront Integration

The frontend deployment automatically creates and configures CloudFront for you:

1. **S3 Bucket**: Creates S3 bucket with static website hosting
2. **Origin Access Identity (OAI)**: Automatically created for secure CloudFront access
3. **CloudFront Distribution**: Automatically deployed and configured to use the S3 bucket
4. **HTTPS**: CloudFront provides HTTPS access with default SSL certificate

No manual CloudFront setup is required - everything is handled by the deployment scripts.

## Deployment Process

### Backend Deployment
1. Packages Lambda functions with dependencies
2. Uploads packages to the artifact S3 bucket
3. Deploys DynamoDB tables
4. Deploys Lambda functions
5. Deploys API Gateway

### Frontend Deployment
1. Builds the Zig application for WebAssembly
2. Creates deployment files
3. Deploys S3 bucket infrastructure
4. Uploads built files to S3 with correct content types

## Troubleshooting

### Common Issues

1. **EMSDK not found**: Make sure Emscripten SDK is installed and `EMSDK` environment variable is set
2. **Zig not found**: Install Zig and add it to your PATH
3. **CloudFormation deployment fails**: Check AWS permissions and CloudFormation stack events
4. **Frontend build fails**: Ensure all Zig dependencies are available and EMSDK is properly configured

### Cleanup

To remove deployed resources:

```bash
# Delete CloudFormation stacks
aws cloudformation delete-stack --stack-name dev-truthbyte-api
aws cloudformation delete-stack --stack-name dev-truthbyte-lambdas
aws cloudformation delete-stack --stack-name dev-truthbyte-dynamodb
aws cloudformation delete-stack --stack-name truthbyte-frontend-s3

# Empty and delete S3 buckets manually if needed
```

## Migration from Old Scripts

The old `deploy.sh` and `deploy.ps1` scripts have been replaced with:
- `deploy-backend.sh` / `deploy-backend.ps1` (same functionality as old scripts)
- `deploy-frontend.sh` / `deploy-frontend.ps1` (new frontend deployment)
- `deploy.sh` / `deploy.ps1` (new master scripts that can deploy either or both)

**Important**: The new master scripts require the `--component` parameter to be explicitly specified. This is a breaking change from any previous behavior that might have assumed a default deployment type. 