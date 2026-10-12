variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, tst, pst, prd)"
  type        = string
}

variable "env_type" {
  description = "Environment Type (Non-prod, prod)"
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

variable "data_sources" {
  description = "Configuration for data sources with prefixes"
  type = map(object({
    enabled           = bool
    uploaded_prefixes = list(string)
  }))
  default = {}
}

variable "business_user_role_arns" {
  description = "IAM role ARNs for business users who upload files (e.g. SSO roles)"
  type        = list(string)
  default     = []
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}
