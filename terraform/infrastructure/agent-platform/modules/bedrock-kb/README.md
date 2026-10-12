# Module: bedrock-kb

Creates a Bedrock Knowledge Base backed by an OpenSearch Serverless vector collection and an S3 data source. The module registers the knowledge base, configures chunking strategy and overlap, and attaches the data source so documents uploaded to S3 can be ingested via the Bedrock console or API. A shared OpenSearch Serverless collection is expected to already exist and be passed in via `opensearch_collection_arn` and `opensearch_collection_endpoint`.

## Usage

```hcl
module "bedrock_kb" {
  source = "./modules/bedrock-kb"

  agent_name     = "pia"
  environment    = "dev"
  kb_bucket_arn  = module.s3_kb_bucket.bucket_arn
  kb_bucket_name = module.s3_kb_bucket.bucket_name

  opensearch_collection_arn      = aws_opensearchserverless_collection.shared.arn
  opensearch_collection_endpoint = aws_opensearchserverless_collection.shared.collection_endpoint
  bedrock_kb_role_arn            = module.iam.bedrock_kb_role_arn

  chunking_strategy = "HIERARCHICAL"
  chunk_size        = 1500
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `agent_name` | Name of the agent | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `kb_bucket_arn` | ARN of the S3 KB bucket | `string` | — | yes |
| `kb_bucket_name` | Name of the S3 KB bucket | `string` | — | yes |
| `kb_s3_prefix` | S3 key prefix for the data source | `string` | `""` | no |
| `embedding_model_arn` | Bedrock embedding model ARN | `string` | `"amazon.titan-embed-text-v2:0"` | no |
| `opensearch_collection_arn` | Shared OpenSearch Serverless collection ARN | `string` | — | yes |
| `opensearch_collection_endpoint` | Shared OpenSearch Serverless collection endpoint | `string` | — | yes |
| `bedrock_kb_role_arn` | IAM role ARN for Bedrock KB service | `string` | — | yes |
| `chunking_strategy` | Chunking strategy (FIXED_SIZE, HIERARCHICAL, NONE) | `string` | `"FIXED_SIZE"` | no |
| `chunk_size` | Tokens per chunk | `number` | `512` | no |
| `overlap_percentage` | Overlap between chunks (%) | `number` | `20` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `knowledge_base_id` | ID of the Bedrock Knowledge Base |
| `knowledge_base_arn` | ARN of the Bedrock Knowledge Base |
| `data_source_id` | ID of the Bedrock data source |
