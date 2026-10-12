variable "agent_name" {
  description = "Name of the agent (e.g., pia, lex)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, tst, pst, prd)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "kb_bucket_arn" {
  description = "ARN of the S3 bucket used for the knowledge base. Leave empty if no KB is needed."
  type        = string
  default     = ""
}

variable "opensearch_collection_arn" {
  description = "ARN of the OpenSearch Serverless collection. Leave empty if no KB is needed."
  type        = string
  default     = ""
}

variable "secret_arns" {
  description = "List of Secrets Manager secret ARNs the ECS task needs to read"
  type        = list(string)
  default     = []
}

variable "additional_iam_statements" {
  description = "Extra IAM policy statements merged into the task_role (e.g., KB retrieve, memory, gateway)"
  type = list(object({
    sid       = string
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "create_kb_role" {
  description = "Whether to create the Bedrock KB IAM role (set true when agent uses a knowledge base)"
  type        = bool
  default     = false
}
