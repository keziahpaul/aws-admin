# ============================================================
# Root variables for the Agent Platform composition root
# ============================================================

variable "environment" {
  description = "Deployment environment (e.g., dev, tst, pst, prd)"
  type        = string
}

variable "project" {
  description = "Project name used in resource naming and tagging"
  type        = string
  default     = "onedata"
}

variable "cost_centre" {
  description = "Cost centre for resource tagging"
  type        = string
  default     = "one-data"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "vpc_id" {
  description = "ID of the VPC in which to deploy agent runtimes and ECS services"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs used by ECS tasks and AgentCore runtimes"
  type        = list(string)
}

variable "create_opensearch_collection" {
  description = "Whether to create a shared OpenSearch Serverless collection for all KB-enabled agents"
  type        = bool
  default     = true
}

variable "use_fargate_spot" {
  description = "Whether to use Fargate Spot capacity for ECS services (cost saving for non-prod)"
  type        = bool
  default     = false
}

variable "agents" {
  description = "List of agent configurations to deploy on the platform"
  type = list(object({
    name                              = string
    enable_agent                      = optional(bool, true)
    container_image                   = string
    slack_bot_image                   = optional(string, "")
    runtime_cpu                       = optional(number, 1024)
    runtime_memory                    = optional(number, 2048)
    slack_bot_cpu                     = optional(number, 256)
    slack_bot_memory                  = optional(number, 512)
    slack_bot_desired_count           = optional(number, 1)
    ecr_snapshot_retention_days       = optional(number, 7)
    ecr_release_image_count           = optional(number, 15)
    ecr_untagged_retention_days       = optional(number, 1)
    enable_kb                         = optional(bool, false)
    enable_memory                     = optional(bool, false)
    enable_gateway                    = optional(bool, false)
    enable_scheduler                  = optional(bool, false)
    enable_slack_bot                  = optional(bool, true)
    kb_s3_prefix                      = optional(string, "")
    kb_chunking_strategy              = optional(string, "FIXED_SIZE")
    kb_chunk_size                     = optional(number, 512)
    kb_hierarchical_parent_chunk_size = optional(number, 1500)
    kb_hierarchical_child_chunk_size  = optional(number, 300)
    kb_hierarchical_overlap_tokens    = optional(number, 60)
    kb_parsing_strategy               = optional(string, "NONE")
    kb_parsing_model_arn              = optional(string, "")
    gateway_instructions              = optional(string, "")
    memory_expiry_days                = optional(number, 90)
    memory_strategies                 = optional(list(object({ type = string, name = string, namespaces = list(string) })), [])
    scheduler_expression              = optional(string, "")
    scheduler_payload                 = optional(map(any), {})
    secrets                           = optional(map(object({ description = optional(string, "") })), {})
    secret_recovery_window_days       = optional(number, 7)
    existing_secret_arns              = optional(map(string), {})
    model_id                          = optional(string, "au.anthropic.claude-sonnet-4-6")
    alarm_sns_emails                  = optional(list(string), [])
    custom_metric_namespace           = optional(string, "")
    additional_iam_statements         = optional(list(object({ sid = string, effect = string, actions = list(string), resources = list(string) })), [])
    additional_environment_variables  = optional(map(string), {})
    tags                              = optional(map(string), {})
  }))
}
