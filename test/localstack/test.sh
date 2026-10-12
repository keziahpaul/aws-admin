#!/bin/bash

set -e

# Set AWS credentials for LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

echo "🚀 Starting LocalStack Empower Infrastructure Test"

# Start LocalStack
echo "📦 Starting LocalStack..."
cd "$(dirname "$0")"
docker compose up -d

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:4566/_localstack/health | grep -q '"s3": "available"'; then
        echo "✅ LocalStack is ready"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

# Final check
if ! curl -s http://localhost:4566/_localstack/health | grep -q '"s3": "available"'; then
    echo "❌ LocalStack S3 service is not available"
    exit 1
fi

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Plan infrastructure
echo "📋 Planning infrastructure..."
terraform plan

# Apply infrastructure
echo "🚀 Applying infrastructure..."
terraform apply -auto-approve

# Test S3 buckets
echo "🧪 Testing S3 buckets..."
aws --endpoint-url=http://localhost:4566 s3 ls

# Test bucket creation
LANDING_BUCKET=$(terraform output -raw landing_bucket_name)
VERIFIED_BUCKET=$(terraform output -raw verified_bucket_name)

echo "📁 Testing bucket access..."
aws --endpoint-url=http://localhost:4566 s3 ls s3://$LANDING_BUCKET
aws --endpoint-url=http://localhost:4566 s3 ls s3://$VERIFIED_BUCKET

# Test Lambda function
echo "⚡ Testing Lambda function..."
LAMBDA_NAME=$(terraform output -raw lambda_function_name)
aws --endpoint-url=http://localhost:4566 lambda list-functions --query "Functions[?FunctionName=='$LAMBDA_NAME']"

# Test file upload and trigger
echo "📤 Testing S3 upload and Lambda trigger..."
echo "test,data,csv" > test_file.csv
aws --endpoint-url=http://localhost:4566 s3 cp test_file.csv s3://$LANDING_BUCKET/uploaded/test_file.csv

# Wait a moment for Lambda to process
sleep 5

# Check Lambda logs
echo "📋 Checking Lambda logs..."
aws --endpoint-url=http://localhost:4566 logs describe-log-groups --query "logGroups[?contains(logGroupName, '$LAMBDA_NAME')]"

echo "✅ LocalStack test completed successfully!"
echo "🧹 Cleaning up..."

# Cleanup
terraform destroy -auto-approve
docker compose down
rm -f test_lambda.py test_lambda.zip test_file.csv

echo "🎉 Test completed and cleaned up!"
