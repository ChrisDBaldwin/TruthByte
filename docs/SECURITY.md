# TruthByte Security Documentation

Comprehensive security measures implemented to protect TruthByte from various attack vectors including injection attacks, abuse, and malicious content.

## Security Architecture Overview

TruthByte implements **defense-in-depth** security with multiple layers of protection:

```
User Access → Authentication → Input Validation → Backend Validation → Database Storage
     ↓              ↓                ↓                    ↓                   ↓
JWT Token     Session         Real-time         Content            Sanitized
Verification  Management      Filtering         Sanitization       Storage
```

### Security Layers

1. **Authentication & Authorization** - JWT-based access control
2. **Input Security** - Real-time validation and sanitization
3. **Backend Validation** - Server-side security enforcement
4. **Data Protection** - Secure storage and transmission

## Authentication & Authorization

### 🔐 JWT-Based Authentication

TruthByte uses **JSON Web Tokens (JWT)** for secure authentication and session management:

**Authentication Flow:**
1. **Token Request**: Client requests JWT from `/session` endpoint
2. **Token Issuance**: Server generates signed JWT with session data
3. **Authenticated Requests**: All API calls include `Authorization: Bearer <token>` header
4. **Token Validation**: Server validates JWT signature and expiration

**Security Features:**
- **HS256 Encryption**: HMAC with SHA-256 for token signing
- **12-Hour Expiration**: Tokens automatically expire for security
- **Session Tracking**: Each token includes unique session identifier
- **Secure Storage**: Tokens handled securely in frontend memory

**Protected Endpoints:**
- `GET /fetch-questions` - Requires valid JWT
- `POST /submit-answers` - Requires valid JWT  
- `POST /propose-question` - Requires valid JWT + rate limiting

**Implementation Details:**
- **Deployment Guide**: See [JWT_DEPLOYMENT.md](JWT_DEPLOYMENT.md) for backend setup
- **Frontend Integration**: See [JWT_FRONTEND.md](JWT_FRONTEND.md) for client implementation
- **Debug Endpoint**: `/ping` endpoint for token validation testing

### 🛡️ Authorization Controls

**User Identification:**
- **UUID v4 Generation**: Cryptographically secure user IDs
- **Persistent Storage**: User IDs stored in browser localStorage
- **Cross-Session Tracking**: Consistent user identity across sessions

**Access Controls:**
- **Authenticated Access**: All game features require valid JWT
- **Rate Limiting**: Question submission limited per user (3/hour, 10/day)
- **Session Validation**: Tokens validated on every request

## Frontend Security (input.zig)

### 🛡️ Real-time Input Protection

**Character Validation:**
- Only printable ASCII characters (32-126) allowed
- Tags restricted to: letters, numbers, spaces, hyphens, underscores
- Binary content immediately blocked

**Content Filtering:**
```zig
// Suspicious patterns detected and blocked
const suspicious_patterns = [_][]const u8{
    "<script", "javascript:", "data:", "vbscript:",
    "onload=", "onerror=", "onclick=", "eval(",
    "document.", "window.", "\\x", "\\u",
    "%3C", "%3E", "&#"  // URL encoded and HTML entities
};
```

**Length Limits:**
- Questions: 10-200 characters
- Tags: 1-50 characters each, maximum 5 tags
- Total tag length: 150 characters maximum

**Spam Detection:**
- Prevents more than 4 consecutive identical characters
- Limits consecutive spaces to 2
- Requires minimum 5 letters in questions

### 🚨 Threat Response

**Immediate Actions on Malicious Content Detection:**
1. Clear input field content
2. Deactivate input field
3. Clear HTML input element
4. Prevent form submission
5. Reset input state

**Binary Injection Prevention:**
- Detects non-printable characters (control codes)
- Blocks image data and binary content
- Prevents clipboard-based binary injection

## Backend Security (propose_question.py)

### 🔒 Server-side Validation

**Comprehensive Input Validation:**
```python
def validate_question_input(question: str, categories: List[str], 
                          title: str = "", passage: str = "") -> Dict[str, Any]:
    # Multi-layer validation with detailed error reporting
```

**Security Checks:**
- **Character validation**: Only safe printable ASCII
- **Pattern detection**: Blocks injection attempts
- **Length enforcement**: Server-side length limits
- **Content analysis**: Meaningful content requirements
- **Regex validation**: Categories must match `^[a-zA-Z0-9\s\-_]+$`

**Content Sanitization:**
```python
def sanitize_text(text: str, max_length: int) -> str:
    # Remove control characters
    # Limit consecutive spaces
    # Trim and enforce length limits
```

### 🚦 Rate Limiting

**Question Submission Limits:**
- **3 questions per hour** per user
- **10 questions per day** per user
- Tracked using DynamoDB with TTL
- HTTP 429 response with Retry-After header

**Implementation:**
```python
def check_rate_limit(user_id: str, current_time: int) -> Dict[str, Any]:
    # Time-window based rate limiting
    # Graceful fallback if rate limiting fails
    # Separate hourly and daily counters
```

## Attack Vector Protection

### 🎯 Cross-Site Scripting (XSS)

**Blocked Patterns:**
- `<script>` tags and variations
- JavaScript URLs (`javascript:`)
- Event handlers (`onload=`, `onclick=`, etc.)
- HTML entities (`&#`, `%3C`, `%3E`)

**Protection Layers:**
1. Frontend: Real-time pattern detection
2. Backend: Server-side validation
3. Sanitization: Content cleaning before storage

### 💉 Code Injection

**SQL Injection Prevention:**
- No direct SQL queries (DynamoDB NoSQL)
- Parameterized operations only
- Input sanitization removes dangerous characters

**Command Injection Prevention:**
- No system commands executed
- Restricted character sets
- Pattern-based blocking

### 🗄️ Binary/Image Injection

**Detection Methods:**
- Control character detection (< ASCII 32)
- File signature analysis
- Content-type validation

**Response:**
- Immediate input clearing
- Field deactivation
- User notification (implicit)

### 📊 Denial of Service (DoS)

**Rate Limiting:**
- Per-user submission limits
- Time-window enforcement
- Graceful degradation

**Resource Protection:**
- Input length limits
- Processing time limits
- Memory usage constraints

## Security Constants

### Frontend Constants (input.zig)
```zig
const MAX_QUESTION_LENGTH = 200;
const MAX_TAG_LENGTH = 50;
const MAX_TAGS_TOTAL_LENGTH = 150;
const MIN_QUESTION_LENGTH = 10;
```

### Backend Constants (propose_question.py)
```python
MAX_QUESTION_LENGTH = 200
MAX_TAG_LENGTH = 50
MAX_TAGS_TOTAL_LENGTH = 150
MIN_QUESTION_LENGTH = 10
MAX_TITLE_LENGTH = 100
MAX_PASSAGE_LENGTH = 500
MAX_TAGS_COUNT = 5
```

## Security Testing

### Manual Testing Scenarios

**Input Validation Tests:**
1. Paste binary content (images, files)
2. Enter script tags and JavaScript
3. Submit oversized content
4. Test with special characters
5. Attempt SQL injection patterns

**Rate Limiting Tests:**
1. Submit 4+ questions within an hour
2. Submit 11+ questions within a day
3. Verify retry-after headers
4. Test concurrent submissions

**Content Filtering Tests:**
1. Various XSS payloads
2. URL-encoded malicious content
3. HTML entity injection
4. Unicode bypass attempts

### Automated Security Measures

**Real-time Monitoring:**
- Input validation failures logged
- Rate limit violations tracked
- Suspicious pattern detection

**Graceful Degradation:**
- Security failures don't break functionality
- Fallback to safe defaults
- User experience preserved

## Security Best Practices

### Development Guidelines

**Input Handling:**
1. **Never trust user input** - validate everything
2. **Sanitize before processing** - clean all content
3. **Use allowlists** - define what's allowed, block everything else
4. **Fail securely** - default to blocking suspicious content

**Error Handling:**
1. **Don't expose internals** - generic error messages
2. **Log security events** - track attempted attacks
3. **Graceful fallbacks** - maintain functionality during security failures

**Testing:**
1. **Test all input vectors** - every user input field
2. **Verify rate limiting** - ensure limits are enforced
3. **Validate sanitization** - confirm dangerous content is cleaned

## Incident Response

### Security Event Detection

**Indicators of Attack:**
- Multiple JWT validation failures from same user
- Rate limit violations
- Suspicious pattern matches in input
- Binary content detection attempts
- Token manipulation or replay attacks
- Unauthorized endpoint access attempts

**Response Actions:**
1. **Log the event** - record details for analysis
2. **Block the content** - prevent malicious input
3. **Rate limit user** - temporary submission restrictions
4. **Alert monitoring** - notify security systems

### Recovery Procedures

**If Security Breach Detected:**
1. **Isolate affected systems** - prevent spread
2. **Analyze attack vectors** - understand the threat
3. **Update security measures** - patch vulnerabilities
4. **Review and test** - ensure fixes are effective

## Security Monitoring

### Metrics to Track

**Input Security:**
- Validation failure rates
- Suspicious pattern detections
- Binary content attempts
- Character set violations

**Rate Limiting:**
- Rate limit hits per user
- Peak submission rates
- Abuse pattern detection

**Authentication Security:**
- JWT token validation failures
- Unauthorized access attempts
- Session expiration events
- Authentication bypass attempts

**System Security:**
- API endpoint access patterns
- Rate limiting violations
- Token manipulation attempts

## Future Security Enhancements

### Planned Improvements

**Advanced Threat Detection:**
- Machine learning based content analysis
- Behavioral pattern recognition
- Advanced spam detection algorithms

**Enhanced Authentication:**
- Token refresh mechanisms
- Multi-factor authentication options
- Enhanced session management
- IP-based access controls

**Enhanced Rate Limiting:**
- Adaptive rate limits based on user behavior
- IP-based rate limiting
- Distributed rate limiting across regions

**Security Monitoring:**
- Real-time security dashboards
- Automated threat response
- Security event correlation
- JWT token analytics and monitoring

---

**Security Review**: This document should be reviewed and updated with each security-related change.  
**Last Updated**: Current as of latest security implementation  
**Version**: 1.0.0 