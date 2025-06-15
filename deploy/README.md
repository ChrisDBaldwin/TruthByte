# TruthByte Deployment

This folder contains all infrastructure-as-code (IaC) and deployment scripts for the TruthByte project, including backend (AWS Lambda, DynamoDB, API Gateway) and frontend (static S3 website) resources.

## Structure

- `infra/` — CloudFormation templates for all AWS resources
  - `dynamodb.yaml` — DynamoDB tables
  - `lambdas.yaml` — Lambda functions and IAM roles
  - `api.yaml` — API Gateway setup
  - `frontend-s3.yaml` — S3 bucket for static frontend hosting
- `scripts/` — Deployment scripts
  - `deploy.sh` — Bash script for backend deployment
  - `deploy.ps1` — PowerShell script for backend deployment
  - (Recommended: add a frontend deploy script, see below)

## Prerequisites

- AWS CLI installed and configured (`aws configure`)
- AWS credentials with permissions for CloudFormation, S3, Lambda, DynamoDB, and API Gateway
- Python 3.13+ and `pip` for Lambda packaging
- (For frontend) A built static site (HTML, JS, WASM) in your frontend build directory

## Backend Deployment

### 1. Deploy Infrastructure & Lambdas

**Bash:**
```sh
cd deploy/scripts
./deploy.sh --environment dev --artifact-bucket <your-artifact-bucket> [--region <aws-region>]
```

**PowerShell:**
```powershell
cd deploy/scripts
./deploy.ps1 -Environment dev -ArtifactBucket <your-artifact-bucket> [-Region <aws-region>]
```

- This will package and upload Lambda functions, then deploy DynamoDB, Lambda, and API Gateway stacks via CloudFormation.
- See the top of each script for required environment variables.

## Frontend (Static S3) Deployment

### 1. Create the S3 Bucket

Deploy the S3 bucket for static hosting using CloudFormation:

```sh
aws cloudformation deploy \
  --template-file ../infra/frontend-s3.yaml \
  --stack-name truthbyte-frontend-s3 \
  --parameter-overrides BucketName="truthbyte.voidtalker.com" CloudFrontOAI="<your-oai-canonical-user-id>"
```
- Replace `<your-oai-canonical-user-id>` with the canonical user ID from your CloudFront OAI (see CloudFront console).
- The bucket will be configured for static website hosting and restricted to CloudFront access.

### 2. Upload Frontend Build

**Bash:**
```sh
aws s3 sync <frontend-build-dir> s3://truthbyte.voidtalker.com/ --delete
```

**PowerShell:**
```powershell
aws s3 sync <frontend-build-dir> s3://truthbyte.voidtalker.com/ --delete
```

- This uploads your built HTML, JS, and WASM files to the S3 bucket.
- Make sure your `index.html` is present at the root of your build directory.

### 3. (Optional) Set Website Configuration

If you want to manually set the index and error documents:
```sh
aws s3 website s3://truthbyte.voidtalker.com/ --index-document index.html --error-document index.html
```

## CloudFront, ACM, and DNS
- Set up a CloudFront distribution with your S3 bucket as the origin (using OAI).
- Request an ACM certificate for `truthbyte.voidtalker.com`.
- Point your domain (A record) to the CloudFront distribution.
- These steps are best done manually or with additional CloudFormation templates.

## Outputs
- The backend API endpoint and S3 website URL are output by the respective CloudFormation stacks.

---

**Tip:**
- For production, always use CloudFront with OAI for secure static site delivery.
- Never enable public read on your S3 bucket unless you understand the risks. 