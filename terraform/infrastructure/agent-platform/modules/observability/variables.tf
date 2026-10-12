variable "agent_name" {
  description = "Name of the agent (e.g., pia, lex)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, tst, pst, prd)"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster to monitor"
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service to monitor"
  type        = string
}

variable "custom_metric_namespace" {
  description = "Override the CloudWatch metric namespace. Defaults to '<AGENT_NAME>/Agent' when empty."
  type        = string
  default     = ""
}

variable "alarm_sns_emails" {
  description = "List of email addresses to subscribe to the alarms SNS topic"
  type        = list(string)
  default     = []
}

variable "error_rate_threshold" {
  description = "Error count threshold that triggers the error rate alarm"
  type        = number
  default     = 5
}

variable "latency_p99_threshold" {
  description = "P99 response latency threshold in milliseconds that triggers the latency alarm"
  type        = number
  default     = 30000
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
