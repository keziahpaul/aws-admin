locals {
  name_prefix    = "${var.environment}-${var.agent_name}-agent"
  function_name  = "${local.name_prefix}-scheduler"
  log_group_name = "/aws/lambda/${local.function_name}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# --- Customer-managed KMS key for EventBridge Scheduler encryption ---
#
# The schedule's target input can carry operational data, so it is encrypted
# with a CMK rather than the AWS-owned default key. The key policy grants the
# account admin rights and lets the EventBridge Scheduler service use the key
# only for this account's schedules.
resource "aws_kms_key" "scheduler" {
  description             = "CMK for ${local.name_prefix} EventBridge Scheduler"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowSchedulerUse"
        Effect    = "Allow"
        Principal = { Service = "scheduler.amazonaws.com" }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "scheduler" {
  name          = "alias/${local.name_prefix}-scheduler"
  target_key_id = aws_kms_key.scheduler.key_id
}

# --- Inline Lambda Source (thin proxy → AgentCore InvokeAgentRuntime) ---

data "archive_file" "scheduler_lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda_scheduler.zip"

  source {
    content  = <<-EOF
      import boto3, json, os
      from botocore.config import Config

      def handler(event, context):
          config = Config(read_timeout=30, connect_timeout=10, retries={"max_attempts": 0})
          client = boto3.client("bedrock-agentcore", region_name=os.environ.get("AWS_REGION", "ap-southeast-2"), config=config)
          payload = json.dumps(event)
          try:
              client.invoke_agent_runtime(
                  agentRuntimeArn=os.environ["AGENT_RUNTIME_ARN"],
                  payload=payload.encode("utf-8"),
                  contentType="application/json",
                  accept="application/json",
              )
          except Exception as e:
              if "ReadTimeout" not in type(e).__name__:
                  raise
          return {"statusCode": 202, "message": "Triggered"}
    EOF
    filename = "lambda_trigger.py"
  }
}

# --- IAM Role for Lambda ---

resource "aws_iam_role" "scheduler_lambda" {
  name = "${local.name_prefix}-scheduler-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  inline_policy {
    name = "InvokeRuntime"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "InvokeAgentRuntime"
          Effect   = "Allow"
          Action   = ["bedrock-agentcore:InvokeAgentRuntime"]
          Resource = ["${var.runtime_arn}*"]
        },
        {
          Sid      = "Logs"
          Effect   = "Allow"
          Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = ["arn:aws:logs:*:*:log-group:${local.log_group_name}:*"]
        }
      ]
    })
  }

  tags = var.tags
}

# --- CloudWatch Log Group for Lambda ---

resource "aws_cloudwatch_log_group" "lambda" {
  name              = local.log_group_name
  retention_in_days = 14

  tags = var.tags
}

# --- Lambda Function ---

resource "aws_lambda_function" "trigger" {
  function_name    = local.function_name
  role             = aws_iam_role.scheduler_lambda.arn
  handler          = "lambda_trigger.handler"
  runtime          = "python3.12"
  timeout          = 60
  filename         = data.archive_file.scheduler_lambda.output_path
  source_code_hash = data.archive_file.scheduler_lambda.output_base64sha256

  environment {
    variables = {
      AGENT_RUNTIME_ARN = var.runtime_arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = var.tags
}

# --- IAM Role for EventBridge Scheduler ---

resource "aws_iam_role" "scheduler" {
  name = "${local.name_prefix}-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "scheduler.amazonaws.com" }
    }]
  })

  inline_policy {
    name = "InvokeLambda"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "InvokeFunction"
          Effect   = "Allow"
          Action   = ["lambda:InvokeFunction"]
          Resource = [aws_lambda_function.trigger.arn]
        },
        {
          Sid      = "UseSchedulerKey"
          Effect   = "Allow"
          Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
          Resource = [aws_kms_key.scheduler.arn]
        },
      ]
    })
  }

  tags = var.tags
}

# --- EventBridge Schedule ---

resource "aws_scheduler_schedule" "this" {
  name       = "${local.name_prefix}-schedule"
  group_name = "default"

  # Encrypt the schedule (including its target input) with the customer-managed
  # key rather than the AWS-owned default key.
  kms_key_arn = aws_kms_key.scheduler.arn

  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = var.schedule_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.trigger.arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode(var.payload)

    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 3
    }
  }
}
