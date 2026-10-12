variable "agent_name" {
  description = "Name of the agent (e.g., pia, lex)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, tst, pst, prd)"
  type        = string
}

variable "kb_bucket_arn" {
  description = "ARN of the S3 bucket used as the KB data source"
  type        = string
}

variable "kb_bucket_name" {
  description = "Name of the S3 bucket used as the KB data source"
  type        = string
}

variable "kb_s3_prefix" {
  description = "S3 key prefix to scope the KB data source ingestion. Empty means all objects."
  type        = string
  default     = ""
}

variable "embedding_model_arn" {
  description = "Full ARN of the Bedrock embedding model (e.g., arn:aws:bedrock:ap-southeast-2::foundation-model/amazon.titan-embed-text-v2:0)"
  type        = string
  default     = "arn:aws:bedrock:ap-southeast-2::foundation-model/amazon.titan-embed-text-v2:0"
}

variable "opensearch_collection_arn" {
  description = "ARN of the shared OpenSearch Serverless collection"
  type        = string
}

variable "opensearch_collection_endpoint" {
  description = "HTTPS endpoint of the shared OpenSearch Serverless collection"
  type        = string
}

variable "bedrock_kb_role_arn" {
  description = "ARN of the IAM role Bedrock assumes to access the KB data source and OpenSearch"
  type        = string
}

variable "chunking_strategy" {
  description = "Chunking strategy for the KB data source ingestion (FIXED_SIZE or NONE)"
  type        = string
  default     = "FIXED_SIZE"
}

variable "chunk_size" {
  description = "Maximum number of tokens per chunk when using FIXED_SIZE chunking"
  type        = number
  default     = 512
}

variable "overlap_percentage" {
  description = "Percentage of token overlap between adjacent chunks when using FIXED_SIZE chunking"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# --- Hierarchical Chunking ---

variable "hierarchical_parent_chunk_size" {
  description = "Max tokens for parent (level 1) chunks when using HIERARCHICAL strategy"
  type        = number
  default     = 1500
}

variable "hierarchical_child_chunk_size" {
  description = "Max tokens for child (level 2) chunks when using HIERARCHICAL strategy"
  type        = number
  default     = 300
}

variable "hierarchical_overlap_tokens" {
  description = "Overlap tokens between chunks when using HIERARCHICAL strategy"
  type        = number
  default     = 60
}

# --- Document Parsing ---

variable "parsing_strategy" {
  description = "Document parsing strategy: NONE (no advanced parsing), BEDROCK_FOUNDATION_MODEL (use Claude to parse images/tables in PDFs), or BEDROCK_DATA_AUTOMATION"
  type        = string
  default     = "NONE"

  validation {
    condition     = contains(["NONE", "BEDROCK_FOUNDATION_MODEL", "BEDROCK_DATA_AUTOMATION"], var.parsing_strategy)
    error_message = "parsing_strategy must be NONE, BEDROCK_FOUNDATION_MODEL, or BEDROCK_DATA_AUTOMATION"
  }
}

variable "parsing_model_arn" {
  description = "ARN of the Bedrock model to use for document parsing (required when parsing_strategy = BEDROCK_FOUNDATION_MODEL). Use inference profile ARN for CRIS compliance."
  type        = string
  default     = ""
}
variable "opensearch_collection_name" {
  description = "Name of the shared OpenSearch Serverless collection"
  type        = string
}

variable "additional_data_access_principals" {
  description = "Additional IAM principal ARNs to grant AOSS data access (e.g., deployment role for bootstrap)"
  type        = list(string)
  default     = []
}
