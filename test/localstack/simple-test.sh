#!/bin/bash

set -e

echo "🚀 Starting LocalStack Empower Infrastructure Test (CLI Mode)"

# Start LocalStack in background
echo "📦 Starting LocalStack..."
localstack start -d

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack to be ready..."
sleep 15

# Check if LocalStack is running
if ! curl -s http://localhost:4566/_localstack/health > /dev/null; then
    echo "❌ LocalStack is not running"
    localstack stop
    exit 1
fi

echo "✅ LocalStack is ready"

# Test S3 bucket creation
echo "🪣 Testing S3 bucket creation..."
aws --endpoint-url=http://localhost:4566 s3 mb s3://onedata-snowflake-ingestion-landing-test
aws --endpoint-url=http://localhost:4566 s3 mb s3://onedata-snowflake-ingestion-verified-test

# List buckets
echo "📋 Listing S3 buckets..."
aws --endpoint-url=http://localhost:4566 s3 ls

# Test IAM role creation
echo "👤 Testing IAM role creation..."
aws --endpoint-url=http://localhost:4566 iam create-role \
    --role-name empower-lambda-role-test \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "lambda.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }'

# Test Secrets Manager
echo "🔐 Testing Secrets Manager..."
aws --endpoint-url=http://localhost:4566 secretsmanager create-secret \
    --name empower/slack-webhook-test \
    --secret-string '{"webhook_url": "https://hooks.slack.com/services/TEST/TEST/TEST"}'

# Test file upload
echo "📤 Testing S3 file upload..."
echo "test,data,csv" > test_file.csv
aws --endpoint-url=http://localhost:4566 s3 cp test_file.csv s3://onedata-snowflake-ingestion-landing-test/uploaded/test_file.csv

# Verify file exists
echo "🔍 Verifying file upload..."
aws --endpoint-url=http://localhost:4566 s3 ls s3://onedata-snowflake-ingestion-landing-test/uploaded/

echo "✅ Basic infrastructure test completed successfully!"

# Cleanup
echo "🧹 Cleaning up..."
rm -f test_file.csv
localstack stop

echo "🎉 LocalStack test completed!"
