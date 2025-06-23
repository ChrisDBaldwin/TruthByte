# JWT Authentication Deployment Guide

This guide covers the deployment of JWT-based authentication for TruthByte, following the Phase 2 operationalization plan.

## ✅ What's Been Implemented

### 1. Backend Infrastructure Updated
- **Lambda Functions**: Added `GetTokenFunction` and `AuthPingFunction` to `lambdas.yaml`
- **API Gateway**: Added `/session` and `/ping` endpoints to `api.yaml`  
- **Environment Variables**: Added `JWT_SECRET` parameter to all Lambda functions
- **Deployment Scripts**: Updated both bash and PowerShell scripts for new functions

### 2. New Lambda Functions Created
- **`backend/lambda/get_token.py`**: Issues JWT tokens at `/session` endpoint
- **`backend/lambda/auth_ping.py`**: Debug endpoint at `/ping` for token validation
- **`backend/shared/auth_utils.py`**: JWT utility functions for create/verify tokens

### 3. Existing Functions Enhanced
- **All existing Lambda functions** now require JWT authentication:
  - `fetch_questions.py` - requires Bearer token
  - `propose_question.py` - requires Bearer token  
  - `submit_answers.py` - requires Bearer token

### 4. Frontend Integration
- **`frontend/truthbyte_bindings.js`** updated with:
  - `init_auth()` function to fetch JWT tokens
  - `_fetchWithAuth()` helper for authenticated requests
  - `auth_ping()` debug function
  - Updated `get_token()` and `get_session_id()` to return real values

## 🚀 Deployment Steps

### Step 1: Generate JWT Secret
Generate a strong, random JWT secret key:
```bash
# Generate a 256-bit (32-byte) random key
openssl rand -hex 32
```
Save this value securely. Perhaps store it in AWS Secrets Manager. It's needed for deployment.

### Step 2: Deploy Backend (Bash)
```bash
cd deploy/scripts
./deploy-backend.sh \
  --environment dev \
  --api-certificate-arn "arn:aws:acm:us-east-1:123456789:certificate/your-cert-id" \
  --jwt-secret "your-generated-jwt-secret-here" \
  --region us-east-1
```

### Step 2: Deploy Backend (PowerShell)
```powershell
cd deploy/scripts
./deploy-backend.ps1 `
  -Environment dev `
  -ApiCertificateArn "arn:aws:acm:us-east-1:123456789:certificate/your-cert-id" `
  -JwtSecret "your-generated-jwt-secret-here" `
  -Region us-east-1
```

### Step 3: Update Frontend Code (Zig Integration)
The Zig frontend code needs to:

1. **Call `init_auth()` at startup**:
```javascript
// Call this before making any API requests
init_auth(callback_function_pointer);
```

2. **Wait for authentication success** before making API calls
3. **Handle authentication failures** gracefully

### Step 4: Test the Implementation

#### Test Token Generation
```bash
curl https://api.truthbyte.voidtalker.com/v1/session
```
Should return:
```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "session_id": "some-session-id",
  "expires_in": 43200
}
```

#### Test Token Validation
```bash
# Get token first
TOKEN=$(curl -s https://api.truthbyte.voidtalker.com/v1/session | jq -r .token)

# Test validation
curl -H "Authorization: Bearer $TOKEN" \
     https://api.truthbyte.voidtalker.com/v1/ping
```
Should return:
```json
{
  "valid": true,
  "payload": {
    "session_id": "some-session-id",
    "exp": 1234567890
  },
  "message": "Token is valid"
}
```

#### Test Protected Endpoints
```bash
# Test fetch questions (now requires auth)
curl -H "Authorization: Bearer $TOKEN" \
     "https://api.truthbyte.voidtalker.com/v1/fetch-questions?num_questions=3"
```

## 🔧 Configuration Notes

### JWT Token Details
- **Algorithm**: HS256 (HMAC with SHA-256)
- **Expiration**: 12 hours from issue time
- **Payload**: Contains `session_id` and `exp` (expiration timestamp)

### Security Considerations
- **JWT Secret**: Store securely, never commit to version control
- **Token Expiration**: 12-hour expiration requires re-authentication 
- **CORS**: Properly configured for `https://truthbyte.voidtalker.com`

### Frontend Integration Points
- **Authentication Flow**: `init_auth()` → get token → make authenticated requests
- **Error Handling**: 401 responses indicate token issues
- **Token Refresh**: Not implemented yet - requires manual re-authentication

## 🐛 Troubleshooting

### Common Issues
1. **401 Unauthorized**: Check JWT_SECRET environment variable matches
2. **Missing Dependencies**: Ensure PyJWT is in requirements.txt  
3. **Import Errors**: Verify shared/ directory is packaged with Lambda functions
4. **CORS Errors**: Check frontend domain matches CORS configuration

### Debug Endpoints
- **`/ping`**: Validates JWT tokens and returns decoded payload
- **`/session`**: Issues new JWT tokens for testing

### Deployment Verification
After deployment, verify these CloudFormation stacks exist:
- `{env}-truthbyte-backend-s3`
- `{env}-truthbyte-dynamodb` 
- `{env}-truthbyte-lambdas`
- `{env}-truthbyte-api`

## 📝 Next Steps (Future Enhancements)

1. **Token Refresh**: Implement refresh token mechanism
2. **Rate Limiting**: Add request rate limiting per session
3. **Audit Logging**: Log authentication events for security monitoring

## ✅ Completed Features

- **User Identity System**: UUID v4 generation with localStorage persistence via `user.zig`
- **User Tracking**: All API calls include X-User-ID header for backend user management
- **Session Management**: User session tracking implemented in DynamoDB with trust scoring

## 🔗 API Endpoints Summary

### Public Endpoints
- `GET /v1/session` - Get JWT token (no auth required)

### Protected Endpoints (require Bearer token)
- `GET /v1/fetch-questions` - Fetch game questions
- `POST /v1/submit-answers` - Submit game answers  
- `POST /v1/propose-question` - Propose new questions

### Debug Endpoints
- `GET /v1/ping` - Validate JWT token (requires Bearer token) 