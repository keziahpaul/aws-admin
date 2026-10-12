# Terraform backend configuration
terraform {
  backend "s3" {}
}

# Extract enabled data sources and their prefixes
locals {
  enabled_data_sources = {
    for key, config in var.data_sources : key => config
    if config.enabled
  }

  # Get all uploaded prefixes from enabled sources (landing bucket)
  uploaded_prefixes = flatten([
    for key, config in local.enabled_data_sources : [
      for prefix in config.uploaded_prefixes : prefix
    ]
  ])

  # Get all config prefixes from enabled sources (verified bucket)
  config_prefixes = flatten([
    for key, config in local.enabled_data_sources : [
      for prefix in config.config_prefixes : prefix
    ]
  ])

  # Get all verified prefixes from enabled sources (verified bucket)
  verified_prefixes = flatten([
    for key, config in local.enabled_data_sources : [
      for prefix in config.verified_prefixes : prefix
    ]
  ])

  # Create S3 triggers for each uploaded prefix
  s3_triggers = [
    for prefix in local.uploaded_prefixes : {
      bucket        = var.source_bucket_name
      events        = ["s3:ObjectCreated:*"]
      filter_prefix = "${prefix}/"
      filter_suffix = ".csv"
    }
  ]
}

module "lambda" {
  source = "../modules/lambda"

  function_name = var.lambda_function_name
  environment   = var.environment
  project       = var.project
  cost_centre   = var.cost_centre

  # Lambda configuration
  runtime     = var.lambda_runtime
  handler     = var.lambda_handler
  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  # Code configuration
  source_path = var.source_path

  # Environment variables - pass enabled applications
  environment_variables = {
    ENVIRONMENT          = var.environment
    S3_LANDING_BUCKET    = var.source_bucket_name
    S3_VERIFIED_BUCKET   = var.target_bucket_name
    SLACK_WEBHOOK_SECRET = var.slack_webhook_secret
    ENABLED_APPLICATIONS = jsonencode(keys(local.enabled_data_sources))
    DATA_SOURCES_CONFIG  = jsonencode(local.enabled_data_sources)
  }

  # IAM policy statements
  policy_statements = [
    # Read uploaded files from landing bucket
    {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:HeadObject"
      ]
      resources = [
        for prefix in local.uploaded_prefixes : "arn:aws:s3:::${var.source_bucket_name}/${prefix}/*"
      ]
      condition = null
    },
    # ListBucket on landing bucket
    {
      effect = "Allow"
      actions = [
        "s3:ListBucket"
      ]
      resources = [
        "arn:aws:s3:::${var.source_bucket_name}"
      ]
      condition = null
    },
    # Delete uploaded files from landing bucket after move, and preserve folder markers
    {
      effect = "Allow"
      actions = [
        "s3:DeleteObject",
        "s3:PutObject"
      ]
      resources = [
        for prefix in local.uploaded_prefixes : "arn:aws:s3:::${var.source_bucket_name}/${prefix}/*"
      ]
      condition = null
    },
    # Read validation config from verified bucket
    {
      effect = "Allow"
      actions = [
        "s3:GetObject"
      ]
      resources = [
        for prefix in local.config_prefixes : "arn:aws:s3:::${var.target_bucket_name}/${prefix}/*"
      ]
      condition = null
    },
    # ListBucket on verified bucket (required for GetObject to return 404 vs AccessDenied)
    {
      effect = "Allow"
      actions = [
        "s3:ListBucket"
      ]
      resources = [
        "arn:aws:s3:::${var.target_bucket_name}"
      ]
      condition = null
    },
    # Write verified files to verified bucket
    {
      effect = "Allow"
      actions = [
        "s3:PutObject"
      ]
      resources = [
        for prefix in local.verified_prefixes : "arn:aws:s3:::${var.target_bucket_name}/${prefix}/*"
      ]
      condition = null
    },
    {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = [
        "*"
      ]
      condition = {
        test     = "StringLike"
        variable = "kms:ViaService"
        values   = ["s3.${var.aws_region}.amazonaws.com"]
      }
    },
    {
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue"
      ]
      resources = [
        "arn:aws:secretsmanager:${var.aws_region}:*:secret:onedata-slack-app-bot-token*"
      ]
      condition = null
    },
    {
      effect = "Allow"
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      resources = [
        "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.lambda_function_name}*"
      ]
      condition = null
    },
    {
      effect = "Allow"
      actions = [
        "sqs:SendMessage"
      ]
      resources = [
        "arn:aws:sqs:${var.aws_region}:*:${var.lambda_function_name}-dlq"
      ]
      condition = null
    },
    {
      effect = "Allow"
      actions = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ]
      resources = ["*"]
      condition = null
    }
  ]

  # S3 trigger configuration - dynamic triggers for each enabled application
  s3_triggers = local.s3_triggers

  tags = {
    Environment = var.environment
    Project     = var.project
    CostCentre  = var.cost_centre
    ManagedBy   = "terragrunt"
  }
}
