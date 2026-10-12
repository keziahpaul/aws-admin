# RDS DNS Resolver Lambda Infrastructure
# This file creates Lambda functions and supporting resources for RDS DNS resolution
# Supports multiple RDS instances, each with their own Private Link NLB

terraform {
  backend "s3" {}
}

# Data source to get the current AWS region
data "aws_region" "current" {}

# Data source to get the current AWS account ID
data "aws_caller_identity" "current" {}

# IAM Role for Lambda execution (shared across all Lambda functions)
resource "aws_iam_role" "rds_dns_resolver_lambda_role" {
  name = "${var.environment}-${var.capability}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.environment}-${var.capability}-lambda-role"
  }
}

# IAM Policy for Lambda function (shared across all Lambda functions)
resource "aws_iam_role_policy" "rds_dns_resolver_lambda_policy" {
  name = "RdsDnsResolverLambdaPolicy"
  role = aws_iam_role.rds_dns_resolver_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeListeners"
        ]
        Resource = "*"
      },
      {
        Action = [
          "ec2:DescribeSubnets"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source {
    content = templatefile("${path.module}/lambda_function.py", {
      # No template variables needed for now
    })
    filename = "index.py"
  }
}

# Create resources for each RDS-NLB mapping
resource "aws_cloudwatch_log_group" "rds_dns_resolver_lambda_log_group" {
  for_each = var.rds_nlb_mappings

  name              = "/aws/lambda/${var.environment}-${var.capability}-${each.key}-lambda"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.environment}-${var.capability}-${each.key}-lambda-logs"
    DBInstance  = each.value.db_identifier
    NLB         = each.value.private_link_nlb
    Description = each.value.description
  }
}

# Random suffix for unique naming
resource "random_id" "signing_profile_suffix" {
  byte_length = 4
}

# Code Signing Profile for Lambda functions
resource "aws_signer_signing_profile" "rds_dns_resolver_signing_profile" {
  platform_id = "AWSLambda-SHA384-ECDSA"
  name        = "${replace(var.environment, "-", "")}${replace(var.capability, "-", "")}lambdasigning${random_id.signing_profile_suffix.hex}"


  signature_validity_period {
    value = 5
    type  = "YEARS"
  }

  tags = {
    Name        = "${var.environment}-${var.capability}-lambda-signing-profile"
    Environment = var.environment
    Capability  = "rds-dns-resolver"                            # Required for IAM policy condition
    Purpose     = "Lambda code signing for security compliance" # Required for IAM policy condition
    Project     = var.project
    CostCentre  = var.cost_centre
  }
}

# Code Signing Configuration for Lambda functions
resource "aws_lambda_code_signing_config" "rds_dns_resolver_code_signing" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.rds_dns_resolver_signing_profile.version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Warn"
  }

  description = "Code signing configuration for ${var.environment}-${var.capability} Lambda functions"

  tags = {
    Name        = "${var.environment}-${var.capability}-lambda-code-signing-config"
    Environment = var.environment
    Capability  = "rds-dns-resolver"                             # Required for IAM policy condition
    Purpose     = "Lambda code signing enforcement for security" # Required for IAM policy condition
    Project     = var.project
    CostCentre  = var.cost_centre
  }
}

# Lambda Function for each RDS-NLB pair
resource "aws_lambda_function" "rds_dns_resolver_lambda" {
  for_each = var.rds_nlb_mappings

  function_name = "${var.environment}-${var.capability}-${each.key}-lambda"
  role          = aws_iam_role.rds_dns_resolver_lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Security: Code signing configuration to ensure only authenticated code runs
  # Temporarily disabled due to existing signing profile conflict
  # code_signing_config_arn = aws_lambda_code_signing_config.rds_dns_resolver_code_signing.arn

  environment {
    variables = {
      ENVIRONMENT      = var.environment
      DB_IDENTIFIER    = each.value.db_identifier
      PRIVATE_LINK_NLB = each.value.private_link_nlb
      TARGET_PORT      = tostring(each.value.port)
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_iam_role_policy.rds_dns_resolver_lambda_policy,
    aws_cloudwatch_log_group.rds_dns_resolver_lambda_log_group,
    # aws_lambda_code_signing_config.rds_dns_resolver_code_signing
  ]

  tags = {
    Name        = "${var.environment}-${var.capability}-${each.key}-lambda"
    DBInstance  = each.value.db_identifier
    NLB         = each.value.private_link_nlb
    Description = each.value.description
  }
}

# EventBridge Rule to trigger Lambda on RDS restart (one per RDS instance)
resource "aws_cloudwatch_event_rule" "eventbridge_trigger_rule" {
  for_each = var.rds_nlb_mappings

  name        = "${var.environment}-${var.capability}-${each.key}-lambda-trigger-rule"
  description = "Rule to trigger the RDS DNS Resolver Lambda function for ${each.value.db_identifier}"
  state       = "ENABLED"

  event_pattern = jsonencode({
    source      = ["aws.rds"]
    detail-type = ["RDS DB Instance Event"]
    detail = {
      EventCategories  = ["restart"]
      SourceIdentifier = [each.value.db_identifier]
    }
  })

  tags = {
    Name        = "${var.environment}-${var.capability}-${each.key}-lambda-trigger-rule"
    DBInstance  = each.value.db_identifier
    NLB         = each.value.private_link_nlb
    Description = each.value.description
  }
}

# EventBridge Target (one per Lambda function)
resource "aws_cloudwatch_event_target" "lambda_target" {
  for_each = var.rds_nlb_mappings

  rule      = aws_cloudwatch_event_rule.eventbridge_trigger_rule[each.key].name
  target_id = "${var.environment}-${var.capability}-${each.key}-lambda-target"
  arn       = aws_lambda_function.rds_dns_resolver_lambda[each.key].arn

  input = jsonencode({
    region          = var.aws_region
    db_identifier   = each.value.db_identifier
    privatelink_nlb = each.value.private_link_nlb
    port            = each.value.port
  })
}

# Lambda Permission for EventBridge (one per Lambda function)
resource "aws_lambda_permission" "rds_dns_resolver_lambda_permission" {
  for_each = var.rds_nlb_mappings

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_dns_resolver_lambda[each.key].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.eventbridge_trigger_rule[each.key].arn
}
