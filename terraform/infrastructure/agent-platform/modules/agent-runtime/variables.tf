variable "agent_name" {
  description = "Name of the agent (e.g., pia, lex)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, tst, pst, prd)"
  type        = string
}

variable "container_image" {
  description = "Container image URI for the AgentCore runtime"
  type        = string
}

variable "iam_role_arn" {
  description = "ARN of the IAM role that the AgentCore runtime assumes"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to place the runtime (required for VPC network mode)"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the runtime (required for VPC network mode)"
  type        = list(string)
}

variable "network_mode" {
  description = "AgentCore runtime network mode. Must be VPC or PUBLIC."
  type        = string
  default     = "VPC"

  validation {
    condition     = contains(["VPC", "PUBLIC"], var.network_mode)
    error_message = "network_mode must be one of: VPC, PUBLIC."
  }
}

variable "base_environment_variables" {
  description = "Standard environment variables injected by the platform into every runtime"
  type        = map(string)
  default     = {}
}

variable "additional_environment_variables" {
  description = "Team-specific environment variables merged on top of base_environment_variables"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14
}

variable "idle_timeout" {
  description = "Seconds of inactivity before an idle AgentCore session is terminated"
  type        = number
  default     = 1800
}

variable "max_lifetime" {
  description = "Maximum lifetime of an AgentCore session in seconds"
  type        = number
  default     = 3600
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "snapshot_retention_days" {
  description = "Days to retain snapshot/dev images (tags prefixed with 'snapshot-') before expiry."
  type        = number
  default     = 7
}

variable "release_image_count" {
  description = "Number of most-recent release/versioned images to keep for rollback."
  type        = number
  default     = 15
}

variable "untagged_retention_days" {
  description = "Days to retain untagged (dangling) images before expiry."
  type        = number
  default     = 1
}
