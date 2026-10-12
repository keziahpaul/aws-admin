variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, tst, pst, prd)"
  type        = string
}

variable "env_type" {
  description = "Environment Type (non-prod, prod)"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "one-data"
}

variable "cost_centre" {
  description = "Cost centre for billing"
  type        = string
  default     = "one-data"
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.9"
}

variable "lambda_handler" {
  description = "Lambda handler"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "source_path" {
  description = "Path to Lambda function source code"
  type        = string
  default     = "lambda/data-ingestion-validation"
}

variable "source_bucket_name" {
  description = "Name of the S3 landing bucket"
  type        = string
}

variable "target_bucket_name" {
  description = "Name of the S3 verified bucket"
  type        = string
}

variable "slack_webhook_secret" {
  description = "Name of the Secrets Manager secret containing Slack webhook URL"
  type        = string
  default     = "data-ingestion/slack-webhook"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "data_sources" {
  description = "Configuration for data sources"
  type = map(object({
    enabled           = bool
    uploaded_prefixes = list(string)
    config_prefixes   = list(string)
    verified_prefixes = list(string)
  }))
  default = {}
}
