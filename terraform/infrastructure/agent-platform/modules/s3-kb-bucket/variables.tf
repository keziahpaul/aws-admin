variable "agent_name" {
  description = "Name of the agent (e.g., pia, lex)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, tst, pst, prd)"
  type        = string
}

variable "project" {
  description = "Project name used in resource naming"
  type        = string
  default     = "onedata"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
