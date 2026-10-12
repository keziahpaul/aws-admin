# Agent Platform Terraform Module

Deploys a multi-agent AI platform on AWS using Bedrock AgentCore. Each agent is declared in the `agents` list and can independently enable a knowledge base (OpenSearch Serverless + S3), persistent memory, an MCP gateway, a Slack bot (ECS Fargate), a cron scheduler, and CloudWatch observability. A single shared OpenSearch Serverless VECTORSEARCH collection is provisioned for all KB-enabled agents in the environment.

## Architecture

```
agents[] ─> module.iam            (task execution + task roles)
         ─> module.secrets        (Secrets Manager)
         ─> module.agent_runtime  (Bedrock AgentCore runtime + ECR)
         ─> module.ecs_service    (Fargate Slack bot, if enable_slack_bot)
         ─> module.s3_kb_bucket   (KB data source bucket, if enable_kb)
         ─> module.bedrock_kb     (Bedrock Knowledge Base, if enable_kb)
         ─> module.agent_memory   (AgentCore memory store, if enable_memory)
         ─> module.agent_gateway  (AgentCore gateway, if enable_gateway)
         ─> module.agent_scheduler (EventBridge schedule, if enable_scheduler)
         ─> module.observability  (CloudWatch dashboard + alarms)

Shared:  aws_opensearchserverless_collection (VECTORSEARCH, if create_opensearch_collection)
```

## Usage

```hcl
module "agent_platform" {
  source = "git::https://github.com/pexa-au/pexa-one-data-aws-admin//terraform/infrastructure/agent-platform?ref=main"

  environment        = "dev"
  vpc_id             = "vpc-0abc123"
  private_subnet_ids = ["subnet-0aaa", "subnet-0bbb"]
  use_fargate_spot   = true

  agents = [
    {
      name            = "pia"
      container_image = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/dev-pia-agent-runtime:latest"
      slack_bot_image = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/dev-pia-agent-slack-bot:latest"
      enable_kb       = true
      enable_memory   = true
      enable_gateway  = true
      enable_slack_bot = true
      secrets         = { slack-bot = { description = "Slack bot + app token" } }
    }
  ]
}
```

## Modules

| Module | Description |
|--------|-------------|
| [iam](./modules/iam/README.md) | ECS task execution/task roles + optional Bedrock KB role |
| [s3-kb-bucket](./modules/s3-kb-bucket/README.md) | Private S3 bucket as KB data source |
| [secrets](./modules/secrets/README.md) | Secrets Manager secrets (created + existing) |
| [agent-runtime](./modules/agent-runtime/README.md) | Bedrock AgentCore runtime + ECR + security group |
| [ecs-service](./modules/ecs-service/README.md) | ECS Fargate service for the Slack bot |
| [bedrock-kb](./modules/bedrock-kb/README.md) | Bedrock Knowledge Base + OpenSearch data source |
| [agent-memory](./modules/agent-memory/README.md) | AgentCore memory store with strategies |
| [agent-gateway](./modules/agent-gateway/README.md) | AgentCore MCP gateway |
| [agent-scheduler](./modules/agent-scheduler/README.md) | EventBridge schedule + Lambda invoker |
| [observability](./modules/observability/README.md) | CloudWatch dashboard + alarms + SNS |

## Requirements

| Requirement | Version |
|-------------|---------|
| Terraform | >= 1.6.0 |
| AWS provider | >= 5.0 |

## Deployment

This module is deployed via Terragrunt. Environment configs live in `environments/`:

```
environments/
  datanp/
    dev/
      terragrunt.hcl    # Main config - merges agent HCL files
      common.hcl        # Environment-specific settings (VPC, subnets)
      agents/
        pia.hcl         # PIA agent definition
        aira.hcl        # AIRA agent definition
    tst/
      terragrunt.hcl
      common.hcl
      agents/
        ...
  dataprd/
    pst/
      ...
    prd/
      ...
```

Each agent is defined in its own HCL file under `agents/`. The `terragrunt.hcl` auto-discovers
all agent files using `fileset()`:

```hcl
locals {
  common = read_terragrunt_config("${get_terragrunt_dir()}/common.hcl")

  # Auto-discover all agent HCL files
  agent_files = fileset("${get_terragrunt_dir()}/agents", "*.hcl")
  agents = [
    for f in local.agent_files :
    read_terragrunt_config("${get_terragrunt_dir()}/agents/${f}").locals.agent
  ]
}

inputs = {
  environment = local.common.locals.environment
  agents      = local.agents
}
```

**Adding a new agent:** Simply create a new `.hcl` file in the `agents/` directory — no
terragrunt.hcl changes required.

CI/CD is managed by `.github/workflows/deploy-agent-platform.yml`.

## Validation

Run the validation script from the repo root to check all environments:

```bash
./scripts/validate-all.sh
```
