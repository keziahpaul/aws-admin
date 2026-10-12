variable "bucket_list" {
  type        = list(string)
  description = "List of S3 bucket names to create"
}

variable "tags" {
  description = "A mapping of tags to assign to resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_id" {
  description = "KMS key ID/ARN to be used for S3 encryption"
  type        = string
}

variable "principal_arns" {
  type        = list(string)
  description = "List of principal ARNs to grant access to the buckets"
  default     = []
}

variable "enable_logs_delivery" {
  type        = bool
  description = "Enable AWS log delivery service access"
  default     = false
}
