# LocalStack Test Configuration for Empower Infrastructure

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "test"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    iam            = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    logs           = "http://localhost:4566"
  }
}

# Test S3 buckets
resource "aws_s3_bucket" "landing" {
  bucket        = "onedata-snowflake-ingest-landing-${data.aws_caller_identity.current.account_id}-${var.environment}"
  force_destroy = true
}

resource "aws_s3_bucket" "verified" {
  bucket        = "onedata-snowflake-ingest-verified-${data.aws_caller_identity.current.account_id}-${var.environment}"
  force_destroy = true
}

# Test IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "empower-lambda-role-test"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "empower-lambda-policy-test"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:HeadObject",
          "s3:CopyObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.landing.arn}/*",
          "${aws_s3_bucket.verified.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.landing.arn,
          aws_s3_bucket.verified.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })
}

# Test Secrets Manager secret for Slack webhook
resource "aws_secretsmanager_secret" "slack_webhook" {
  name = "empower/slack-webhook-test"
}

resource "aws_secretsmanager_secret_version" "slack_webhook" {
  secret_id = aws_secretsmanager_secret.slack_webhook.id
  secret_string = jsonencode({
    webhook_url = "https://hooks.slack.com/services/TEST/TEST/TEST"
  })
}

# Test Lambda function (placeholder)
resource "aws_lambda_function" "empower_validation" {
  filename         = "test_lambda.zip"
  function_name    = "empower-validation-test"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      ENVIRONMENT           = "test"
      S3_LANDING_BUCKET    = aws_s3_bucket.landing.bucket
      S3_VERIFIED_BUCKET   = aws_s3_bucket.verified.bucket
      SLACK_WEBHOOK_SECRET = aws_secretsmanager_secret.slack_webhook.name
    }
  }

  depends_on = [null_resource.test_lambda_zip]
}

# Create a dummy Lambda zip file
resource "null_resource" "test_lambda_zip" {
  provisioner "local-exec" {
    command = <<EOF
echo 'def lambda_handler(event, context): return {"statusCode": 200}' > test_lambda.py
zip test_lambda.zip test_lambda.py
EOF
  }
}

# S3 bucket notification
resource "aws_s3_bucket_notification" "lambda_trigger" {
  bucket = aws_s3_bucket.landing.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.empower_validation.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploaded/"
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.empower_validation.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.landing.arn
}

# Outputs
output "landing_bucket_name" {
  value = aws_s3_bucket.landing.bucket
}

output "verified_bucket_name" {
  value = aws_s3_bucket.verified.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.empower_validation.function_name
}
