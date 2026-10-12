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
  description = "Environment name (np, prd)"
  type        = string
}

variable "env_type" {
  description = "Environment type for SCIM tokens (nonprod or prod)"
  type        = string
}

variable "snowflake_accounts" {
  description = "List of Snowflake account names for SCIM token secrets"
  type        = list(string)
}

variable "rotator_role_arn" {
  description = "ARN of the IAM role used by the SCIM token rotator (GitHub Actions)"
  type        = string
}

variable "okta_role_arn" {
  description = "ARN of the Okta team's IAM role for cross-account access"
  type        = string
}
