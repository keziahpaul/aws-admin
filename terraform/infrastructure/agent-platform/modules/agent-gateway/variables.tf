variable "agent_name" {
  description = "Name of the agent (e.g., pia, lex)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, tst, pst, prd)"
  type        = string
}

variable "instructions" {
  description = "Gateway-level MCP tool instructions/description"
  type        = string
  default     = ""
}

variable "authorizer_type" {
  description = "Authorizer type for the AgentCore Gateway"
  type        = string
  default     = "AWS_IAM"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
