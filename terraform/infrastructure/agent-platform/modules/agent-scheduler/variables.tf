variable "agent_name" {
  description = "Name of the agent (e.g., pia, lex)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, tst, pst, prd)"
  type        = string
}

variable "runtime_arn" {
  description = "ARN of the AgentCore runtime to invoke on schedule"
  type        = string
}

variable "schedule_expression" {
  description = "EventBridge schedule expression (e.g., cron(0 12 * * ? *) or rate(1 hour))"
  type        = string
}

variable "schedule_timezone" {
  description = "IANA timezone for the schedule expression (e.g., Australia/Melbourne)"
  type        = string
  default     = "UTC"
}

variable "payload" {
  description = "Map of key-value pairs to send as JSON payload to the runtime invocation"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
