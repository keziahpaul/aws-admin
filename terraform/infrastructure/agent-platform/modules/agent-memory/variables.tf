variable "agent_name" {
  description = "Name of the agent (e.g., pia, lex)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, tst, pst, prd)"
  type        = string
}

variable "event_expiry_days" {
  description = "Number of days before memory events are automatically expired"
  type        = number
  default     = 90
}

variable "memory_strategies" {
  description = "List of memory strategy configurations to attach to the memory store"
  type = list(object({
    type       = string
    name       = string
    namespaces = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
