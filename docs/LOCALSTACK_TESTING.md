# LocalStack Testing Guide for Empower Data Acquisition

## Overview

This document provides comprehensive testing procedures for the Empower Data Acquisition infrastructure using LocalStack. It covers both Docker-based and non-Docker testing approaches to accommodate different development environments.

## Prerequisites

### Required Tools
- **LocalStack CLI**: `pip install localstack`
- **AWS CLI**: For interacting with LocalStack endpoints
- **Terraform**: For infrastructure validation
- **Docker** (for Docker-based testing): Docker Desktop or Docker Engine

### Optional Tools
- **Terragrunt**: For full infrastructure deployment testing
- **Python 3.9+**: For Lambda function testing
- **curl**: For health checks and API testing

## Testing Approaches

### 1. Docker-Based Testing (Recommended)

**Advantages:**
- Full service emulation (S3, Lambda, IAM, Secrets Manager, CloudWatch)
- Persistent state during testing session
- Closest to AWS production environment
- Supports Lambda execution with containers

**Requirements:**
- Docker running and accessible
- Sufficient system resources (2GB+ RAM recommended)

#### Quick Start - Docker Testing

```bash
# Navigate to test directory
cd test/localstack

# Start LocalStack with Docker Compose
docker compose up -d

# Wait for services to be ready (30-60 seconds)
sleep 30

# Run comprehensive infrastructure test
./test.sh

# Cleanup
docker compose down
```

#### Manual Docker Testing

```bash
# Start LocalStack
docker compose up -d

# Check service health
curl http://localhost:4566/_localstack/health

# Initialize Terraform
terraform init
terraform plan
terraform apply -auto-approve

# Test S3 operations
aws --endpoint-url=http://localhost:4566 s3 ls
aws --endpoint-url=http://localhost:4566 s3 mb s3://test-bucket

# Test Lambda deployment
aws --endpoint-url=http://localhost:4566 lambda list-functions

# Test end-to-end workflow
echo "test,data,csv" > test.csv
aws --endpoint-url=http://localhost:4566 s3 cp test.csv s3://landing-bucket/uploaded/

# Check Lambda logs
aws --endpoint-url=http://localhost:4566 logs describe-log-groups

# Cleanup
terraform destroy -auto-approve
docker compose down
```

### 2. Non-Docker Testing (Alternative)

**Advantages:**
- No Docker dependency
- Faster startup time
- Lower resource usage
- Good for CI/CD environments without Docker

**Limitations:**
- Limited service emulation
- No Lambda execution
- Basic S3/IAM testing only

#### Quick Start - Non-Docker Testing

```bash
# Navigate to test directory
cd test/localstack

# Run simplified CLI test
./simple-test.sh
```

#### Manual Non-Docker Testing

```bash
# Start LocalStack in background
localstack start -d

# Wait for startup
sleep 15

# Check health
curl http://localhost:4566/_localstack/health

# Test S3 bucket operations
aws --endpoint-url=http://localhost:4566 s3 mb s3://test-landing
aws --endpoint-url=http://localhost:4566 s3 mb s3://test-verified

# Test IAM role creation
aws --endpoint-url=http://localhost:4566 iam create-role \
    --role-name test-lambda-role \
    --assume-role-policy-document file://trust-policy.json

# Test Secrets Manager
aws --endpoint-url=http://localhost:4566 secretsmanager create-secret \
    --name test/slack-webhook \
    --secret-string '{"webhook_url": "https://hooks.slack.com/test"}'

# Test file upload
echo "name,email,date" > test.csv
aws --endpoint-url=http://localhost:4566 s3 cp test.csv s3://test-landing/uploaded/

# Verify upload
aws --endpoint-url=http://localhost:4566 s3 ls s3://test-landing/uploaded/

# Cleanup
localstack stop
rm test.csv
```

### 3. Configuration Validation (No External Dependencies)

**Advantages:**
- No external service dependencies
- Fast execution
- Validates Terraform/Terragrunt syntax
- Good for pre-commit hooks

```bash
# Run syntax validation
./test/validate-syntax.sh

# Run manual configuration test
./test/manual-config-test.sh
```

## Test Scenarios

### Scenario 1: Basic Infrastructure Validation

**Objective**: Verify S3 buckets, IAM roles, and basic configurations

**Docker Approach**:
```bash
cd test/localstack
docker compose up -d
terraform init && terraform apply -auto-approve
# Verify outputs
terraform output
docker compose down
```

**Non-Docker Approach**:
```bash
cd test/localstack
./simple-test.sh
```

### Scenario 2: End-to-End File Processing

**Objective**: Test complete workflow from file upload to processing

**Docker Approach Only** (requires Lambda execution):
```bash
cd test/localstack
docker compose up -d
terraform apply -auto-approve

# Upload test file
echo "name,email,date\nJohn,john@example.com,2024-01-01" > test.csv
aws --endpoint-url=http://localhost:4566 s3 cp test.csv s3://$(terraform output -raw landing_bucket_name)/uploaded/

# Wait for Lambda processing
sleep 10

# Check if file moved to verified bucket
aws --endpoint-url=http://localhost:4566 s3 ls s3://$(terraform output -raw verified_bucket_name)/

# Check Lambda logs
aws --endpoint-url=http://localhost:4566 logs describe-log-groups

docker compose down
```

### Scenario 3: Error Handling and Notifications

**Objective**: Test validation failures and Slack notifications

**Docker Approach**:
```bash
# Upload invalid CSV
echo "invalid,csv,content,extra" > invalid.csv
aws --endpoint-url=http://localhost:4566 s3 cp invalid.csv s3://landing-bucket/uploaded/

# Check Lambda logs for error handling
aws --endpoint-url=http://localhost:4566 logs filter-log-events \
    --log-group-name /aws/lambda/empower-validation-test

# Verify file remains in uploaded/ (not moved)
aws --endpoint-url=http://localhost:4566 s3 ls s3://landing-bucket/uploaded/
```

## Troubleshooting

### Common Issues

#### Docker Issues
```bash
# Issue: Docker daemon not running
# Solution: Start Docker Desktop or Docker service
sudo systemctl start docker  # Linux
open -a Docker  # macOS

# Issue: Port 4566 already in use
# Solution: Stop existing LocalStack instance
localstack stop
docker stop $(docker ps -q --filter ancestor=localstack/localstack)

# Issue: Permission denied
# Solution: Check Docker permissions
sudo usermod -aG docker $USER  # Linux
```

#### LocalStack Issues
```bash
# Issue: Services not ready
# Solution: Wait longer or check health endpoint
curl http://localhost:4566/_localstack/health

# Issue: AWS CLI authentication
# Solution: Use test credentials
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Issue: Terraform module download
# Solution: Ensure internet connectivity for module downloads
terraform init -upgrade
```

#### Lambda Issues (Docker only)
```bash
# Issue: Lambda function not found
# Solution: Check function deployment
aws --endpoint-url=http://localhost:4566 lambda list-functions

# Issue: Lambda timeout
# Solution: Check function logs
aws --endpoint-url=http://localhost:4566 logs describe-log-groups
aws --endpoint-url=http://localhost:4566 logs get-log-events \
    --log-group-name /aws/lambda/function-name
```

### Debug Commands

```bash
# Check LocalStack status
curl http://localhost:4566/_localstack/health | jq

# List all S3 buckets
aws --endpoint-url=http://localhost:4566 s3api list-buckets

# Check IAM roles
aws --endpoint-url=http://localhost:4566 iam list-roles

# List Lambda functions
aws --endpoint-url=http://localhost:4566 lambda list-functions

# Check Secrets Manager secrets
aws --endpoint-url=http://localhost:4566 secretsmanager list-secrets

# View CloudWatch log groups
aws --endpoint-url=http://localhost:4566 logs describe-log-groups
```

## Test Scripts Reference

### Available Test Scripts

| Script | Purpose | Dependencies | Duration |
|--------|---------|--------------|----------|
| `test.sh` | Full Docker-based test | Docker, Terraform | 2-3 min |
| `simple-test.sh` | CLI-based test | LocalStack CLI | 1-2 min |
| `validate-syntax.sh` | Syntax validation | Terraform | 30 sec |
| `manual-config-test.sh` | Configuration validation | None | 15 sec |

### Test Script Usage

```bash
# Full test suite (requires Docker)
cd test/localstack && ./test.sh

# Quick validation (no dependencies)
./test/validate-syntax.sh && ./test/manual-config-test.sh

# CLI test (requires LocalStack CLI)
cd test/localstack && ./simple-test.sh
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: LocalStack Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup LocalStack
        run: |
          pip install localstack
          docker pull localstack/localstack:latest
      
      - name: Run Tests
        run: |
          cd test/localstack
          ./test.sh
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit
./test/validate-syntax.sh
./test/manual-config-test.sh
```

## Best Practices

### Development Workflow
1. **Start with syntax validation** - fastest feedback
2. **Use manual config test** - validates logic without external deps
3. **Run CLI test** - basic service interaction
4. **Full Docker test** - comprehensive validation before deployment

### Performance Tips
- Use `docker compose` instead of `docker-compose` (newer, faster)
- Set `LOCALSTACK_VOLUME_DIR` to persist data between runs
- Use `DEBUG=0` in production CI to reduce log noise
- Limit services to only what you need: `SERVICES=s3,lambda,iam`

### Security Considerations
- LocalStack is for testing only - never use in production
- Test credentials are hardcoded - safe for local development
- Clean up test resources to avoid conflicts
- Use isolated test buckets/resources

## Conclusion

This testing framework provides comprehensive validation of the Empower Data Acquisition infrastructure across different environments and constraints. Choose the appropriate testing approach based on your development environment and requirements:

- **Docker testing** for full validation
- **CLI testing** for quick verification
- **Syntax validation** for immediate feedback
- **Manual testing** for CI/CD pipelines

All approaches ensure the infrastructure is properly configured and ready for AWS deployment.
