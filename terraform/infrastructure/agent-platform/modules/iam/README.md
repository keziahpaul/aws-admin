# Module: iam

Creates the IAM roles required by an Agent Platform agent: an ECS task execution role (ECR pull + Secrets Manager read), an ECS task role (Bedrock, CloudWatch, optional KB/memory/gateway permissions), and an optional Bedrock KB service role when a KB S3 bucket is provided. Additional policy statements can be injected via `additional_iam_statements` to grant agent-specific permissions (e.g., cross-account Bedrock KB access). All roles follow least-privilege principles and are scoped to the specified agent and environment.

## Usage

```hcl
module "iam" {
  source     = "./modules/iam"

  agent_name = "pia"
  environment = "dev"
  aws_region  = "ap-southeast-2"
  account_id  = "042775015153"

  kb_bucket_arn             = module.s3_kb_bucket.bucket_arn
  opensearch_collection_arn = aws_opensearchserverless_collection.shared.arn
  secret_arns               = [module.secrets.secret_arns_list]

  additional_iam_statements = [
    {
      sid       = "BedrockRetrieve"
      effect    = "Allow"
      actions   = ["bedrock:Retrieve", "bedrock:RetrieveAndGenerate"]
      resources = ["arn:aws:bedrock:ap-southeast-2:042775015153:knowledge-base/*"]
    }
  ]
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `agent_name` | Name of the agent (e.g., pia) | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `aws_region` | AWS region | `string` | — | yes |
| `account_id` | AWS account ID | `string` | — | yes |
| `kb_bucket_arn` | ARN of the KB S3 bucket (empty = no KB role) | `string` | `""` | no |
| `opensearch_collection_arn` | ARN of the OpenSearch Serverless collection | `string` | `""` | no |
| `secret_arns` | List of Secrets Manager ARNs | `list(string)` | `[]` | no |
| `additional_iam_statements` | Extra IAM statements for the task role | `list(object)` | `[]` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `task_execution_role_arn` | ARN of the ECS task execution role |
| `task_execution_role_name` | Name of the ECS task execution role |
| `task_role_arn` | ARN of the ECS task role |
| `task_role_name` | Name of the ECS task role |
| `bedrock_kb_role_arn` | ARN of the Bedrock KB service role (empty if no KB) |
| `bedrock_kb_role_name` | Name of the Bedrock KB service role (empty if no KB) |
