# TruthByte Documentation

This directory contains all project documentation, specifications, and guides organized for easy reference by developers and AI agents.

## 📋 Documentation Structure

### Core Specifications
- **[`ARCHITECTURE.md`](ARCHITECTURE.md)** - Complete system architecture and technical overview
- **[`AGENTIC_SPECS.md`](AGENTIC_SPECS.md)** - AI agent coding specifications and patterns
- **[`API_REFERENCE.md`](API_REFERENCE.md)** - Complete API endpoint documentation

### Component Documentation  
- **[`BACKEND.md`](BACKEND.md)** - Python Lambda backend architecture and development
- **[`FRONTEND.md`](FRONTEND.md)** - Zig/WASM frontend with modular architecture
- **[`DATABASE.md`](DATABASE.md)** - DynamoDB schema and data management
- **[`DEPLOYMENT.md`](DEPLOYMENT.md)** - Infrastructure deployment and DevOps

### Authentication & Security
- **[`JWT_DEPLOYMENT.md`](JWT_DEPLOYMENT.md)** - JWT authentication deployment guide
- **[`JWT_FRONTEND.md`](JWT_FRONTEND.md)** - Frontend JWT integration guide

### Development Guides
- **[`SCRIPTS.md`](SCRIPTS.md)** - Data processing and utility scripts
- **[`BACKEND_ZIG.md`](BACKEND_ZIG.md)** - Experimental Zig backend (on ice)

## 🎯 Quick Reference

### For New Developers
1. Start with [`ARCHITECTURE.md`](ARCHITECTURE.md) for system overview
2. Read [`DEPLOYMENT.md`](DEPLOYMENT.md) for setup instructions
3. Check component-specific docs for detailed development info

### For AI Agents
- [`AGENTIC_SPECS.md`](AGENTIC_SPECS.md) contains comprehensive patterns and conventions
- [`API_REFERENCE.md`](API_REFERENCE.md) has complete endpoint specifications
- Component docs contain detailed technical implementation details

### For DevOps/Deployment
- [`DEPLOYMENT.md`](DEPLOYMENT.md) - Infrastructure and deployment procedures
- [`JWT_DEPLOYMENT.md`](JWT_DEPLOYMENT.md) - Authentication setup
- [`DATABASE.md`](DATABASE.md) - Data management and schema

## 🏗️ Project Architecture Overview

```
TruthByte Game (WASM/Zig) ←→ API Gateway ←→ Lambda Functions ←→ DynamoDB
        ↕                        ↕                 ↕              ↕
   Mobile/Desktop UI        CloudFormation    Python Backend   Tag-Based Data
```

## 📝 Documentation Standards

- **Markdown Format**: All docs use GitHub-flavored Markdown
- **AI-Friendly**: Written for both human developers and AI assistants
- **Code Examples**: Include working code snippets and API examples
- **Architecture Diagrams**: Visual representations where helpful
- **Update Requirements**: Keep docs synchronized with code changes

## Latest Updates

### Daily Mode Feature (NEW)
TruthByte now includes a comprehensive daily mode system with deterministic questions, streak tracking, and performance ranking.

**Key Features:**
- **Daily Challenge**: 10 deterministic questions, same for all users each day
- **Streak System**: Daily streaks with performance requirements (≥70% for continuation)
- **Ranking System**: Letter grades (S, A, B, C, D) based on percentage correct
- **Progress Tracking**: Persistent daily completion status and historical performance

**New Lambda Functions:**
- `fetch_daily_questions` - Provides deterministic daily questions
- `submit_daily_answers` - Processes daily submissions with score calculation

**Frontend Updates:**
- Mode selection interface (Arcade, Categories, Daily)
- Daily review screen with score and rank display
- Streak counters and progress indicators
- Mobile-optimized daily mode UI

**Database Schema:**
- New Users table with daily progress tracking
- Daily completion status and streak management
- Historical performance data storage

### Development Tools (NEW)
- **Single Lambda Deployment**: `deploy-single-lambda.ps1` for rapid individual function deployment
- **Enhanced Backend Functions**: Updated existing lambdas with improved category support
- **Improved Error Handling**: Better error messages and debug information across all lambdas

---

**Last Updated**: Current as of latest codebase state  
**Maintained By**: Development team and automated documentation tools 