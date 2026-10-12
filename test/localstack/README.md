# LocalStack Testing for Empower Infrastructure

## Overview
This directory contains LocalStack configuration to test the Empower Data Acquisition infrastructure locally before deploying to AWS.

## Prerequisites
- Docker and Docker Compose
- Terraform
- AWS CLI
- LocalStack installed

## Services Tested
- **S3**: Landing and verified buckets with proper access controls
- **Lambda**: Validation function with S3 triggers
- **IAM**: Roles and policies for Lambda execution
- **Secrets Manager**: Slack webhook configuration
- **CloudWatch Logs**: Lambda logging

## Usage

### Quick Test
```bash
cd test/localstack
./test.sh
```

### Manual Testing
```bash
# Start LocalStack
docker-compose up -d

# Initialize and apply Terraform
terraform init
terraform plan
terraform apply

# Test S3 operations
aws --endpoint-url=http://localhost:4566 s3 ls
aws --endpoint-url=http://localhost:4566 s3 cp test.csv s3://bucket-name/uploaded/

# Test Lambda function
aws --endpoint-url=http://localhost:4566 lambda list-functions

# Cleanup
terraform destroy
docker-compose down
```

## Test Coverage
- ✅ S3 bucket creation with security settings
- ✅ IAM roles and policies for Lambda
- ✅ S3 event notifications to Lambda
- ✅ Secrets Manager integration
- ✅ Lambda function deployment
- ✅ End-to-end file upload trigger

## Validation Points
1. **Security**: Public access blocked on S3 buckets
2. **Permissions**: Lambda can read/write to appropriate buckets
3. **Triggers**: S3 ObjectCreated events invoke Lambda
4. **Configuration**: Environment variables properly set
5. **Secrets**: Slack webhook accessible from Lambda
