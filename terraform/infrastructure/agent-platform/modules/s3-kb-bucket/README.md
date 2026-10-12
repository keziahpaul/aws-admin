# Module: s3-kb-bucket

Creates a private, encrypted S3 bucket for use as a Bedrock Knowledge Base data source. The bucket enforces SSL-only access, blocks all public access, and enables server-side encryption with AWS-managed keys. It is scoped to a single agent and environment so each agent has an isolated knowledge store.

## Usage

```hcl
module "s3_kb_bucket" {
  source = "./modules/s3-kb-bucket"

  agent_name  = "pia"
  environment = "dev"
  project     = "onedata"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `agent_name` | Name of the agent | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `project` | Project name for resource naming | `string` | `"onedata"` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_name` | Name of the S3 bucket |
| `bucket_arn` | ARN of the S3 bucket |
| `bucket_id` | ID (name) of the S3 bucket |
