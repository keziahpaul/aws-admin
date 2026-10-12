variable "environment" {
  description = "Environment name (dev, tst, pst, prf02, prd)"
  type        = string
}

variable "account" {
  description = "AWS Account ID"
  type        = string
}

variable "onedata_account" {
  description = "Onedata AWS Account ID"
  type        = string
}

variable "min_dcu" {
  description = "Minimum Data Capacity Units"
  type        = number
}

variable "max_dcu" {
  description = "Maximum Data Capacity Units"
  type        = number
}

variable "dms_subnet_group" {
  description = "DMS Subnet Group ID"
  type        = string
}

variable "security_group_id" {
  description = "Security Group ID"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "onedata-exchange"
}

variable "cost_centre" {
  description = "Cost centre for billing"
  type        = string
  default     = "onedata"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "preferred_maintenance_window" {
  description = "Preferred maintenance window for DMS replication"
  type        = string
  default     = "Sun:11:00-Sun:13:00"
}

variable "max_full_load_sub_tasks" {
  description = "Maximum number of tables to load in parallel during full load"
  type        = number
  default     = 24
}

