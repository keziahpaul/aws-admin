# Module: agent-runtime

Deploys an AWS Bedrock AgentCore runtime and its associated endpoint for a single agent. Creates an ECR repository for the runtime container image, a security group, a CloudWatch log group, and registers the runtime in AgentCore VPC mode. Environment variables are layered: a set of standard platform variables (agent name, environment, region, model ID) is merged with any team-specific variables provided via `additional_environment_variables`.

## Usage

```hcl
module "agent_runtime" {
  source = "./modules/agent-runtime"

  agent_name         = "pia"
  environment        = "dev"
  container_image    = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/dev-pia-agent-runtime:latest"
  iam_role_arn       = module.iam.task_role_arn
  vpc_id             = "vpc-0abc123"
  private_subnet_ids = ["subnet-0aaa", "subnet-0bbb"]

  base_environment_variables = {
    AGENT_NAME  = "pia"
    ENVIRONMENT = "dev"
    MODEL_ID    = "au.anthropic.claude-sonnet-4-6"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `agent_name` | Name of the agent | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `container_image` | Container image URI | `string` | — | yes |
| `iam_role_arn` | IAM role ARN the runtime assumes | `string` | — | yes |
| `vpc_id` | VPC ID | `string` | — | yes |
| `private_subnet_ids` | Private subnet IDs | `list(string)` | — | yes |
| `network_mode` | Runtime network mode (VPC or PUBLIC) | `string` | `"VPC"` | no |
| `base_environment_variables` | Standard platform environment variables | `map(string)` | `{}` | no |
| `additional_environment_variables` | Team-specific environment variables | `map(string)` | `{}` | no |
| `log_retention_days` | CloudWatch log retention in days | `number` | `14` | no |
| `idle_timeout` | Session idle timeout in seconds | `number` | `1800` | no |
| `max_lifetime` | Maximum session lifetime in seconds | `number` | `3600` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `runtime_arn` | ARN of the AgentCore runtime |
| `runtime_id` | ID of the AgentCore runtime |
| `runtime_endpoint_arn` | ARN of the runtime endpoint |
| `ecr_repository_url` | ECR repository URL for the runtime image |
| `security_group_id` | ID of the runtime security group |
| `log_group_arn` | ARN of the CloudWatch log group |
