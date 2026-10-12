data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Archive Lambda source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_path
  output_path = "/tmp/lambda_${var.function_name}.zip"
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

# IAM policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for stmt in var.policy_statements : merge(
        {
          Effect   = stmt.effect
          Action   = stmt.actions
          Resource = stmt.resources
        },
        stmt.condition != null ? {
          Condition = {
            "${stmt.condition.test}" = {
              "${stmt.condition.variable}" = stmt.condition.values
            }
          }
        } : {}
      )
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "function" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = var.handler
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size

  reserved_concurrent_executions = var.reserved_concurrent_executions
  kms_key_arn                    = var.kms_key_arn

  environment {
    variables = var.environment_variables
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  tracing_config {
    mode = "Active"
  }

  tags = var.tags
}

# Dead Letter Queue for Lambda
resource "aws_sqs_queue" "dlq" {
  name = "${var.function_name}-dlq"
  tags = var.tags
}

# S3 bucket notifications - group triggers by bucket to avoid overwriting
resource "aws_s3_bucket_notification" "lambda_trigger" {
  for_each = { for bucket in distinct([for t in var.s3_triggers : t.bucket]) : bucket => [
    for t in var.s3_triggers : t if t.bucket == bucket
  ] }

  bucket = each.key

  dynamic "lambda_function" {
    for_each = each.value
    content {
      lambda_function_arn = aws_lambda_function.function.arn
      events              = lambda_function.value.events
      filter_prefix       = lambda_function.value.filter_prefix
      filter_suffix       = lambda_function.value.filter_suffix
    }
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# Lambda permission for S3 to invoke
resource "aws_lambda_permission" "allow_s3" {
  for_each = { for bucket in distinct([for t in var.s3_triggers : t.bucket]) : bucket => bucket }

  statement_id  = "AllowExecutionFromS3-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${each.value}"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14

  tags = var.tags
}
