# backend-zig

**Status: On Ice**  
This section of the repo is currently on hold. The goal was to implement backend logic to Zig, but due to the significant effort required to implement AWS SDK tooling in Zig, active development is paused for now. We'll keep this directory as a reminder and starting point for a future, gradual port.

## What's Here

- **AWS Lambda Boilerplate:**  
  The structure is set up for building AWS Lambda functions in Zig, including a custom build script and a basic Lambda runtime library under `lib/aws-lambda/`.
- **Example Entrypoint:**  
  The `src/main.zig` file demonstrates a simple main function that calls a placeholder utility for submitting an answer.
- **Utility Stubs:**  
  `src/utils.zig` contains a stub for submitting answers, with comments indicating where DynamoDB integration would go.
- **AWS Lambda Library:**  
  The `lib/aws-lambda/` directory contains early-stage code for Lambda runtime, event handling, and utilities, but is not yet integrated with AWS services.

## Why Pause?

Implementing full AWS SDK support (DynamoDB, Lambda event sources, etc.) in Zig is a large undertaking. Rather than rush or duplicate effort, this section will be ported over slowly as time and upstream Zig ecosystem improvements allow.

## How to Use

Currently, this code is not production-ready and is not integrated with AWS. It serves as a reference and a starting point for future Zig backend work.

To build the example (does not actually connect to AWS):

```sh
zig build run
```

## Future Plans

- Gradually port backend logic to Zig as AWS SDK support matures.
- Implement DynamoDB and other AWS integrations as time allows.
- Use this as a testbed for Zig-based serverless development.
