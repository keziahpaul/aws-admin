variable "agent_name" {
  description = "Name of the agent (e.g., pia, lex)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, tst, pst, prd)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to place the ECS service"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ECS tasks"
  type        = list(string)
}

variable "runtime_arn" {
  description = "ARN of the AgentCore runtime (used as an environment variable in the ECS task)"
  type        = string
}

variable "slack_bot_image" {
  description = "Container image URI for the Slack bot sidecar"
  type        = string
}

variable "task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task IAM role"
  type        = string
}

variable "secret_arns" {
  description = "Map of logical name to Secrets Manager secret ARN for injection into the task"
  type        = map(string)
}

variable "kb_knowledge_base_id" {
  description = "ID of the Bedrock Knowledge Base. Leave empty if no KB is used by this agent."
  type        = string
  default     = ""
}

variable "desired_count" {
  description = "Desired number of ECS task instances"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "ECS task CPU units"
  type        = number
  default     = 256
}

variable "memory" {
  description = "ECS task memory in MiB"
  type        = number
  default     = 512
}

variable "use_fargate_spot" {
  description = "Whether to use Fargate Spot capacity provider for cost savings (suitable for non-prod)"
  type        = bool
  default     = false
}

variable "create_alb_target_group" {
  description = "Whether to create an ALB target group. Set to false for Slack Socket Mode agents."
  type        = bool
  default     = false
}

variable "create_ecr_repository" {
  description = "Whether to create an ECR repository for the Slack bot image"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "memory_id" {
  description = "AgentCore Memory ID for Canvas lifecycle persistence"
  type        = string
  default     = ""
}

variable "memory_strategy_id" {
  description = "AgentCore Memory Strategy ID"
  type        = string
  default     = ""
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
