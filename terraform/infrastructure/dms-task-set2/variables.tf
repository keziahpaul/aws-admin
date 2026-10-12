variable "environment" {
  type        = string
  description = "Environment identifier (dev, tst, pst, prd)"
}

variable "account" {
  type        = string
  description = "AWS Account ID for the deployment"
}

variable "onedata_account" {
  type        = string
  description = "Onedata AWS Account ID for cross-account references"
}

variable "min_dcu" {
  type        = number
  description = "Minimum Data Capacity Units for serverless scaling"
}

variable "max_dcu" {
  type        = number
  description = "Maximum Data Capacity Units for serverless scaling"
}

variable "dms_subnet_group" {
  type        = string
  description = "DMS Subnet Group ID for networking configuration"
}

variable "security_group_id" {
  type        = string
  description = "Security Group ID for DMS task networking"
}

variable "aws_region" {
  type        = string
  description = "AWS region for resource deployment"
  default     = "ap-southeast-2"
}

variable "project" {
  type        = string
  description = "Project name for resource tagging"
  default     = "snowflake"
}

variable "cost_centre" {
  type        = string
  description = "Cost centre for resource tagging"
  default     = "one-data"
}