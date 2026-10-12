variable "agent_name" {
  description = "Name of the agent (e.g., pia, lex)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, tst, pst, prd)"
  type        = string
}

variable "secrets" {
  description = "Map of secrets to create. Key is the secret short name; value is a config object."
  type = map(object({
    description = optional(string, "")
  }))
  default = {}
}

variable "existing_secret_arns" {
  description = "Map of existing Secrets Manager secret ARNs to reference (BYO secrets). Key is a logical name; value is the ARN."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "recovery_window_in_days" {
  description = "Secrets Manager recovery window. Set to 0 to force-delete immediately (useful in dev for destroy/recreate cycles); keep >= 7 in prod for an accidental-deletion safety net."
  type        = number
  default     = 7
}
