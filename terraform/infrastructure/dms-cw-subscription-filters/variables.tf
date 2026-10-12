variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "onedata"
}

variable "cost_centre" {
  description = "Cost centre for billing"
  type        = string
  default     = "onedata"
}

variable "environment" {
  description = "Environment name (dev, tst, pst, prd)"
  type        = string
}

variable "dms_task_ids" {
  description = "List of DMS task unique IDs (e.g., ['WHVFP5XJKJFKTHVUQN5A3VKN6Y'])"
  type        = list(string)
}

variable "log_group_pattern" {
  description = "Optional regex pattern to filter log groups (e.g., '.*onedata-projects.*'). Leave empty to include all groups."
  type        = string
  default     = ""
}

variable "firehose_delivery_stream_arn" {
  description = "ARN of the Firehose delivery stream created by Splunk team"
  type        = string
}

variable "subscription_filter_role_arn" {
  description = "ARN of the IAM role for CloudWatch Logs subscription filter"
  type        = string
}
