# TruthByte Deployment Scripts

This directory contains deployment scripts for both the backend and frontend components of TruthByte.

**🚀 Current Status**: Frontend deployment is fully functional with mobile-optimized builds and AWS S3/CloudFront integration.

## Structure

```
deploy/
├── scripts/
│   ├── deploy.sh                 # Master deployment script (Bash)
│   ├── deploy.ps1                # Master deployment script (PowerShell)
│   ├── deploy-backend.sh         # Backend-only deployment (Bash)
│   ├── deploy-backend.ps1        # Backend-only deployment (PowerShell)
│   ├── deploy-frontend.sh        # Frontend-only deployment (Bash)
│   ├── deploy-frontend.ps1       # Frontend-only deployment (PowerShell)
│   └── deploy-single-lambda.ps1  # **NEW** Single lambda deployment (PowerShell)
├── artifacts/                    # Generated deployment files (gitignored)
│   └── frontend/                 # Built WASM, JS, HTML files
└── infra/
    ├── backend-s3.yaml           # S3 bucket for Lambda artifacts
    ├── dynamodb.yaml             # DynamoDB tables (questions + tag mapping)
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

## Frontend Deployment (Working)

The frontend deployment is fully functional and optimized for mobile devices.

### Quick Deploy

```bash
# Bash (Linux/macOS/WSL)
cd deploy
./scripts/deploy-frontend.sh --bucket-name your-domain.com --certificate-id YOUR_ACM_CERT_ID

# PowerShell (Windows)
cd deploy
.\scripts\deploy-frontend.ps1 -BucketName your-domain.com -CertificateId YOUR_ACM_CERT_ID
```

### Deployment Process

1. **Build Optimization**: Compiles Zig to WASM with `ReleaseFast` optimization
2. **Mobile Optimization**: Includes touch input system and iOS Safari fixes
3. **File Generation**: Creates optimized `index.html`, `index.js`, `index.wasm`
4. **S3 Upload**: Uploads with proper content-type headers and cache-control
5. **CloudFront Integration**: Automatic CDN setup with HTTPS support

### Mobile Features Included

- **Touch Input System**: Custom JavaScript coordinate capture for raylib-zig WASM compatibility
- **iOS Safari Optimizations**: Prevents zoom, bounce scrolling, touch callouts
- **Visual Viewport API**: Proper mobile browser UI handling
- **Responsive Canvas**: Automatic canvas resizing for all screen sizes
- **Cross-Platform Input**: Unified mouse/touch/keyboard event handling

### Cache Strategy

- **HTML Files**: `Cache-Control: no-cache` (always check for updates)
- **Static Assets**: `Cache-Control: max-age=3600` (1 hour caching)
- **Content-Type**: Proper MIME types for all file types

## Backend Deployment (Production Ready)

The backend deployment creates a high-performance, tag-based architecture that avoids expensive table scans. All infrastructure is automatically created and configured for optimal performance.

### Usage

```bash
# Bash
./scripts/deploy-backend.sh --environment dev

# PowerShell
.\scripts\deploy-backend.ps1 -Environment dev
```

## Master Deployment Scripts

The master deployment scripts can deploy backend, frontend, or both components.

#### Bash (Linux/macOS/WSL)

```bash
# Deploy everything
./scripts/deploy.sh \
  --component all \
  --environment dev \
  --bucket my-website.com \
  --certificate-id YOUR_CERT_ID

# Deploy only frontend
./scripts/deploy.sh \
  --component frontend \
  --bucket my-website.com \
  --certificate-id YOUR_CERT_ID

# Show help
./scripts/deploy.sh --help
```

#### PowerShell (Windows)

```powershell
# Deploy everything
.\scripts\deploy.ps1 `
  -Component all `
  -Environment dev `
  -Bucket my-website.com `
  -CertificateId YOUR_CERT_ID

# Deploy only frontend
.\scripts\deploy.ps1 `
  -Component frontend `
  -Bucket my-website.com `
  -CertificateId YOUR_CERT_ID

# Show help
.\scripts\deploy.ps1 -Help
```

## Parameters

### Master Script Parameters
- `--component` / `-Component`: What to deploy (backend|frontend|all) **[Required]**

### Common Parameters
- `--region` / `-Region`: AWS region (default: us-east-1)

### Backend Parameters
- `--environment` / `-Environment`: Deployment environment (dev|prod) **[Required]**

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
4. **HTTPS**: CloudFront provides HTTPS access with ACM certificate
5. **Mobile Optimization**: Proper headers and caching for mobile performance

No manual CloudFront setup is required - everything is handled by the deployment scripts.

## Technical Implementation Details

### Build System
- **Native Build**: Uses `main_hot.zig` with hot-reload for development
- **Web Build**: Uses `main_release.zig` with WASM compilation for deployment
- **Optimization**: `ReleaseFast` mode for production builds

### Input System Architecture
- **Unified Input Events**: `InputEvent` struct handles mouse/touch/keyboard
- **JavaScript Workaround**: Custom coordinate capture for raylib-zig WASM limitations
- **State Tracking**: Proper press/release event handling
- **Cross-Platform**: Works on desktop and mobile devices

### File Structure
```
artifacts/frontend/
├── index.html          # Mobile-optimized HTML shell
├── index.js            # Emscripten-generated JavaScript
├── index.wasm          # Compiled WebAssembly binary
└── truthbyte_bindings.js # Custom JavaScript bindings
```

## Troubleshooting

### Common Issues

1. **EMSDK not found**: Make sure Emscripten SDK is installed and `EMSDK` environment variable is set
2. **Zig not found**: Install Zig and add it to your PATH
3. **Touch input not working**: Ensure you're testing the web build (`main_release.zig`), not native build
4. **CloudFormation deployment fails**: Check AWS permissions and CloudFormation stack events
5. **Frontend build fails**: Ensure all Zig dependencies are available and EMSDK is properly configured

### Testing Deployment Locally

Before deploying, test the web build locally:

```bash
cd frontend
zig build -Dtarget=wasm32-emscripten -Doptimize=ReleaseFast
python -m http.server 8000
# Open http://localhost:8000/zig-out/bin/game.html
```

This tests the exact same build that gets deployed.

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

The deployment scripts have been simplified and optimized:

### Changes Made
- **Simplified File Handling**: Direct file copying instead of asset fingerprinting
- **Improved Mobile Support**: Enhanced touch input and iOS Safari compatibility
- **Better Error Handling**: More robust deployment process
- **Cross-Platform Scripts**: Both Bash and PowerShell versions maintained
- **Optimized Caching**: Balanced cache strategy for performance and updates

### Breaking Changes
- Asset fingerprinting has been removed for simplicity
- Cache headers have been adjusted for shorter-term caching
- Build artifacts now go to `deploy/artifacts/` directory (gitignored)

## Current Status

✅ **Frontend Deployment**: Fully functional with mobile optimization  
✅ **Backend Deployment**: Production-ready with tag-based architecture  
✅ **Mobile Support**: Complete touch input system with iOS Safari fixes  
✅ **AWS Integration**: S3 + CloudFront deployment working  
✅ **Cross-Platform**: Bash and PowerShell scripts maintained

## Data Upload

After deploying the backend infrastructure, upload your question data using the provided script:

### Upload Questions to DynamoDB

```bash
# Upload questions with automatic tag processing
python scripts/upload_questions.py --environment dev --file data/dev_with_ids.jsonl

# For production environment
python scripts/upload_questions.py --environment prod --file data/dev_with_ids.jsonl
```

### Data Processing Features

- **Automatic Tag Enhancement**: Every question gets a `general` tag for universal queries
- **Dual-Table Upload**: Populates both questions table and tag mapping table
- **Batch Operations**: Efficient bulk upload using DynamoDB batch operations
- **Progress Tracking**: Real-time upload progress and error reporting
- **Smart Detection**: Automatically detects table schema and adapts upload strategy

### Expected Data Format

Questions should be in JSONL format with these fields:
```json
{
  "id": "q001",
  "question": "does ethanol take more energy make that produces", 
  "title": "Ethanol fuel",
  "passage": "All biomass goes through at least some of these steps...",
  "answer": false,
  "tags": ["geography", "literature", "science", "business"]
}
```

### Performance Benefits

- **No Table Scans**: All queries use efficient tag-based indexing
- **Sub-second Queries**: Fast response times regardless of dataset size  
- **Predictable Costs**: Consistent, low-cost operation
- **High Throughput**: Supports concurrent requests without performance degradation 

## Single Lambda Deployment (NEW)

For rapid development and testing, you can now deploy individual Lambda functions without going through the full backend deployment process.

### Quick Lambda Deploy

```powershell
# Deploy a single Lambda function
.\scripts\deploy-single-lambda.ps1 -Environment dev -FunctionName fetch-daily-questions

# Deploy modified function for testing
.\scripts\deploy-single-lambda.ps1 -Environment dev -FunctionName submit-daily-answers
```

### Available Functions

All Lambda functions can be deployed individually:
- `fetch-questions` - Question retrieval
- `submit-answers` - Answer processing
- `propose-question` - Question submission
- `get-token` - Authentication
- `auth-ping` - Token validation
- `get-user` - User data retrieval
- `get-categories` - Category listing
- `get-user-submissions` - User submissions
- `approve-question` - Question approval
- `fetch-daily-questions` - **NEW** Daily question retrieval
- `submit-daily-answers` - **NEW** Daily answer processing

### How Single Lambda Deployment Works

1. **Dependency Management**: Automatically installs Python dependencies for the specific function
2. **Shared Code Inclusion**: Includes shared auth utilities for functions that need them
3. **Fast Packaging**: Uses 7-Zip if available for faster compression, falls back to PowerShell
4. **Direct Upload**: Uploads to S3 and updates Lambda function code directly
5. **Immediate Availability**: Function is available immediately after deployment

### Benefits

- **Fast Iteration**: Deploy single functions in seconds vs. full backend deployment
- **Selective Updates**: Only update the functions you've changed
- **Development Workflow**: Perfect for testing individual Lambda changes
- **Cost Efficient**: Only redeploys what's needed

### Requirements

- Backend infrastructure must already be deployed (creates necessary S3 buckets and Lambda functions)
- AWS CLI configured with appropriate permissions
- Python 3.13+ with pip for dependency installation 