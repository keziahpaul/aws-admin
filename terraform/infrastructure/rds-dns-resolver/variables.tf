variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "The environment to deploy the resources"
  type        = string
}

variable "project" {
  description = "The name of the project"
  type        = string
}

variable "cost_centre" {
  description = "The cost centre for the project"
  type        = string
}

variable "capability" {
  description = "The capability/service name"
  type        = string
  default     = "rds-dns-resolver"
}

variable "rds_nlb_mappings" {
  description = "Map of RDS DB identifiers to their corresponding Private Link NLB names"
  type = map(object({
    db_identifier    = string
    private_link_nlb = string
    port             = optional(number, 5432)
    description      = optional(string, "")
  }))

  # Example:
  # rds_nlb_mappings = {
  #   "primary-db" = {
  #     db_identifier    = "my-primary-rds-instance"
  #     private_link_nlb = "primary-nlb-name"
  #     port            = 5432
  #     description     = "Primary database for application"
  #   }
  #   "analytics-db" = {
  #     db_identifier    = "my-analytics-rds-instance"
  #     private_link_nlb = "analytics-nlb-name"
  #     port            = 5432
  #     description     = "Analytics database"
  #   }
  # }
}

variable "log_retention_days" {
  description = "Number of days to retain Lambda CloudWatch logs"
  type        = number
  default     = 30
}

variable "retain_lambda_logs" {
  description = "Whether to retain Lambda CloudWatch logs after stack deletion"
  type        = bool
  default     = true
}
