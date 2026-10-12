# Module: ecs-service

Creates an ECS Fargate service running the Slack bot container for an agent. Provisions an ECS cluster, task definition, service, security group, CloudWatch log group, and an optional ECR repository for the Slack bot image. Secrets from Secrets Manager are injected as environment variables. Supports Fargate Spot for cost savings in non-production environments. This module is only needed for agents that expose a Slack interface (`enable_slack_bot = true`).

## Usage

```hcl
module "ecs_service" {
  source = "./modules/ecs-service"

  agent_name         = "pia"
  environment        = "dev"
  vpc_id             = "vpc-0abc123"
  private_subnet_ids = ["subnet-0aaa", "subnet-0bbb"]

  runtime_arn             = module.agent_runtime.runtime_arn
  slack_bot_image         = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/dev-pia-agent-slack-bot:latest"
  task_execution_role_arn = module.iam.task_execution_role_arn
  task_role_arn           = module.iam.task_role_arn
  secret_arns             = module.secrets.secret_arns

  use_fargate_spot = true
  cpu              = 256
  memory           = 512
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `agent_name` | Name of the agent | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `vpc_id` | VPC ID | `string` | — | yes |
| `private_subnet_ids` | Private subnet IDs | `list(string)` | — | yes |
| `runtime_arn` | AgentCore runtime ARN | `string` | — | yes |
| `slack_bot_image` | Slack bot container image URI | `string` | — | yes |
| `task_execution_role_arn` | ECS task execution role ARN | `string` | — | yes |
| `task_role_arn` | ECS task role ARN | `string` | — | yes |
| `secret_arns` | Map of secret name to ARN | `map(string)` | — | yes |
| `kb_knowledge_base_id` | Bedrock KB ID (empty if no KB) | `string` | `""` | no |
| `desired_count` | Desired task count | `number` | `1` | no |
| `cpu` | Task CPU units | `number` | `256` | no |
| `memory` | Task memory in MiB | `number` | `512` | no |
| `use_fargate_spot` | Use Fargate Spot capacity | `bool` | `false` | no |
| `create_ecr_repository` | Create an ECR repository for the Slack bot | `bool` | `true` | no |
| `log_retention_days` | CloudWatch log retention in days | `number` | `14` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_name` | ECS cluster name |
| `cluster_arn` | ECS cluster ARN |
| `service_name` | ECS service name |
| `service_arn` | ECS service ARN |
| `ecr_repository_url` | ECR repository URL for the Slack bot image |
| `security_group_id` | ECS task security group ID |
