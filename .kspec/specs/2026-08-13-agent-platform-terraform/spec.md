# Reusable Agent Platform Terraform Modules

**Jira**: [DD-6600](https://pexa.atlassian.net/browse/DD-6600)
**Epic**: [DD-6592](https://pexa.atlassian.net/browse/DD-6592) - PIA Agent - PEXA Incident Assistant
**Created**: 2026-08-13
**Revised**: 2026-08-13 (v2 - platform layer + custom agent layer)

---

## Problem Statement

PEXA's AI agents (Lex, Vulnerability Agent, PIA) share 70-80% identical Terraform code — ECR repos, ECS clusters, IAM boilerplate, security groups, log groups. Each agent repo copy-pastes this and drifts independently. New teams wanting to build agents must reverse-engineer existing repos, leading to inconsistent security posture, missed best practices, and slow onboarding.

## Context

- **Current State**: Lex and Vulnerability Agent each have their own Terraform in their repos (`terraform/compliance-agent/`, `terraform/agentcore/`). ~400 lines of copy-pasted boilerplate per agent with minor variations.
- **Target State**: A library of versioned, Git-referenced Terraform modules in `pexa-one-data-aws-admin` that agent teams compose selectively. Teams pick only what they need and extend with custom resources.
- **Business Impact**: New agent from zero to deployed infra in hours, not weeks. Security and observability guardrails enforced by default. No duplication drift.

## Design Philosophy

### Two-Layer Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    AGENT REPO (team-owned)                    │
│                                                              │
│  Custom Layer (team decides what to add):                    │
│  - AgentCore Gateway targets (vuln-agent)                    │
│  - Cedar policies (vuln-agent)                               │
│  - EventBridge schedules (vuln-agent)                        │
│  - Bedrock Guardrails (Lex)                                  │
│  - Canvas API integration (PIA)                              │
│  - Additional secrets (Nucleus API key, etc.)                │
│  - Custom IAM statements for agent-specific permissions      │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Platform Layer (shared modules, Git-referenced):            │
│  - agent-runtime      (MUST HAVE)                            │
│  - agent-slack-bot    (MUST HAVE for Slack agents)           │
│  - agent-secrets      (MUST HAVE)                            │
│  - agent-observability (MUST HAVE)                           │
│  - agent-bedrock-kb   (OPTIONAL - if agent uses RAG)        │
│  - agent-memory       (OPTIONAL - if agent needs sessions)  │
│  - agent-scheduler    (OPTIONAL - if agent has cron jobs)    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
         │
         │  source = "git::git@github.com:PEXA-AU/
         │            pexa-one-data-aws-admin.git//
         │            terraform/modules/agent-*?ref=v1.0"
         ▼
┌──────────────────────────────────────────────────────────────┐
│              pexa-one-data-aws-admin (this repo)              │
│                                                              │
│  terraform/modules/                                          │
│    agent-runtime/                                            │
│    agent-slack-bot/                                          │
│    agent-secrets/                                            │
│    agent-observability/                                      │
│    agent-bedrock-kb/                                         │
│    agent-memory/                                             │
│    agent-scheduler/                                          │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Principles

1. **Pick what you need** — Modules are independent. No "all-or-nothing" composition root.
2. **Platform enforces guardrails** — Security group egress-only, log retention, ECR scanning, tagging all baked in. Teams cannot accidentally skip these.
3. **Custom extends, never forks** — Teams add agent-specific resources alongside platform modules, never copy-paste and modify the module itself.
4. **Escape hatches exist** — Every module exposes `additional_*` variables for team-specific overrides (IAM statements, environment variables, secrets, tags).
5. **Versioned via Git ref** — Teams pin to `?ref=v1.0.0`. Platform upgrades are opt-in. Breaking changes require major version bump.
6. **Opinionated defaults, overridable** — CPU=256, memory=512, retention=14d, desired_count=1. All overridable.

---

## Requirements

### Platform Modules (Shared - in aws-admin)

#### M1: `agent-runtime` (MUST HAVE)

The AgentCore Runtime — every agent needs this.

Creates:
- `awscc_bedrockagentcore_runtime` with container config, VPC networking, lifecycle settings
- `aws_ecr_repository` (agent image) with scan-on-push, lifecycle policy
- `aws_security_group` (egress-only for runtime)
- `aws_iam_role` (agentcore runtime role) with base permissions (Bedrock invoke, ECR pull, VPC networking)
- `aws_cloudwatch_log_group` (runtime logs, vendedlogs path)

Extension points:
- `additional_iam_statements` — list of IAM statement objects to merge into the runtime role (e.g., KB retrieve, memory, gateway, guardrail, PutMetricData)
- `additional_environment_variables` — map of env vars to inject (e.g., KNOWLEDGE_BASE_ID, GATEWAY_ARN, MEMORY_ID)
- `additional_secrets` — map of secret ARNs to add to SecretsRead policy

```hcl
module "runtime" {
  source = "git::...//terraform/modules/agent-runtime?ref=v1.0"

  agent_name         = "pia"
  environment        = "dev"
  container_image    = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/onedata-pia-agent-dev:latest"
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids

  # PIA-specific: add KB retrieve permission
  additional_iam_statements = [
    {
      sid       = "BedrockRetrieve"
      effect    = "Allow"
      actions   = ["bedrock:Retrieve"]
      resources = ["arn:aws:bedrock:ap-southeast-2:*:knowledge-base/*"]
    },
    {
      sid       = "CloudWatchMetrics"
      effect    = "Allow"
      actions   = ["cloudwatch:PutMetricData"]
      resources = ["*"]
      condition = { test = "StringEquals", variable = "cloudwatch:namespace", values = ["PIA/Agent"] }
    },
  ]

  additional_environment_variables = {
    KNOWLEDGE_BASE_ID   = module.kb.knowledge_base_id
    SUPERVISOR_MODEL_ID = "au.anthropic.claude-opus-4"
  }
}
```

#### M2: `agent-slack-bot` (MUST HAVE for Slack agents)

The ECS Fargate service running the Slack bot (Socket Mode, outbound only).

Creates:
- `aws_ecr_repository` (slack bot image) with lifecycle
- `aws_ecs_cluster` with Container Insights
- `aws_ecs_task_definition` (single container, secrets injected)
- `aws_ecs_service` with rolling deploy
- `aws_security_group` (egress-only)
- `aws_iam_role` (task role: InvokeAgentRuntime + SecretsRead + Logs)
- `aws_iam_role` (execution role: ECR pull + SecretsRead)
- `aws_cloudwatch_log_group`

Extension points:
- `desired_count` — default 1, set 2 for HA (like Lex)
- `cpu` / `memory` — defaults 256/512
- `additional_task_iam_statements` — extra permissions for the task role
- `additional_environment_variables` — extra env vars
- `additional_secrets` — extra secrets to inject into the container
- `deployment_minimum_healthy_percent` / `deployment_maximum_percent`

#### M3: `agent-secrets` (MUST HAVE)

Creates Secrets Manager entries with a standard structure.

Creates:
- `aws_secretsmanager_secret` per entry with `ignore_changes = [secret_string]` (values set out-of-band)
- Optional CloudWatch alarm on secret age > 90 days

Extension points:
- `secrets` — map of secret names to create (flexible, not hardcoded to Slack)
- `existing_secret_arns` — map of secret names to ARNs that already exist (BYO pattern — just outputs the ARN without creating)

```hcl
module "secrets" {
  source = "git::...//terraform/modules/agent-secrets?ref=v1.0"

  agent_name  = "pia"
  environment = "dev"

  # Create these secrets (values injected manually post-deploy)
  secrets = {
    "slack-bot" = { description = "Slack bot token + app token JSON" }
  }

  # Reference existing secrets without creating (vuln-agent pattern)
  existing_secret_arns = {}
}
```

#### M4: `agent-observability` (MUST HAVE)

Standardised monitoring that every agent gets.

Creates:
- `aws_cloudwatch_dashboard` with template widgets (ECS CPU/memory, log errors, invocation count)
- `aws_cloudwatch_metric_alarm` (ECS unhealthy tasks)
- `aws_sns_topic` + subscriptions (optional)

Extension points:
- `additional_widgets` — list of widget JSON objects to append to the dashboard
- `custom_alarms` — list of alarm configs beyond the default
- `custom_metric_namespace` — agent-specific namespace (e.g., "PIA/Agent", "Lex/Compliance")
- `alarm_actions` — override SNS topic ARN (BYO existing topic)

#### M5: `agent-bedrock-kb` (OPTIONAL — RAG agents only)

Creates:
- `aws_s3_bucket` (KB source documents) with versioning, lifecycle, Bedrock bucket policy
- OpenSearch Serverless collection + data access policy
- `aws_bedrockagent_knowledge_base` + data source (S3)

Extension points:
- `existing_s3_bucket_arn` — skip bucket creation, use existing (BYO)
- `existing_aoss_collection_arn` — share collection across agents (cost saving)
- `chunking_strategy` — FIXED_SIZE | HIERARCHICAL | SEMANTIC
- `chunk_size` / `overlap`
- `embedding_model` — default Titan V2, overridable

#### M6: `agent-memory` (OPTIONAL — session/dedup agents only)

Creates:
- `awscc_bedrockagentcore_memory` with configurable strategies

Extension points:
- `memory_strategies` — list of strategy objects (semantic, summary, etc.)
- `event_expiry_duration` — retention in days
- `namespace_templates` — per-strategy namespace patterns

#### M7: `agent-gateway` (OPTIONAL — agents with external tool integrations)

AgentCore Gateway for MCP tool access. Now a shared module since multiple agents need it (Vuln uses Nucleus/Slack/Jira, PIA will use Prisma AIRS MCP and ChatGPT Enterprise exposure).

Creates:
- `awscc_bedrockagentcore_gateway` with MCP protocol config
- `aws_iam_role` (gateway execution role)

Extension points:
- `gateway_targets` — list of target configs (name, type, endpoint). Note: actual target registration may require Python script for complex OpenAPI/built-in targets until awscc supports `GatewayTarget` as a resource.
- `instructions` — gateway-level tool instructions
- `authorizer_type` — default AWS_IAM, overridable
- `additional_gateway_iam_statements` — extra permissions for the gateway role

```hcl
module "gateway" {
  source = "git::...//terraform/modules/agent-gateway?ref=v1.0"

  agent_name  = "pia"
  environment = "dev"

  instructions = "PIA incident tools: Prisma AIRS MCP for security context."

  # Targets registered post-apply via scripts/register_gateway_targets.py
}
```

#### M8: `agent-scheduler` (OPTIONAL — cron/batch agents only)

Creates:
- `aws_lambda_function` (thin invocation proxy)
- `aws_scheduler_schedule` (EventBridge)
- IAM roles for both

Extension points:
- `schedule_expression` — cron or rate
- `payload` — JSON input to the agent runtime
- `retry_policy` — max attempts, age

---

### Non-Functional Requirements

- **NF1**: All modules MUST tag resources with `project`, `environment`, `agent_name`, `managed_by=terraform`
- **NF2**: Terraform >= 1.0, AWS provider ~> 5.0, AWSCC provider ~> 1.0
- **NF3**: Region: ap-southeast-2 only (all resources)
- **NF4**: No public endpoints — all security groups egress-only, no ALB unless explicitly opted in
- **NF5**: ECR scan-on-push enabled by default
- **NF6**: Log retention minimum 14 days (overridable)
- **NF7**: Modules MUST NOT assume other modules exist — no implicit cross-module dependencies
- **NF8**: Modules expose outputs that other modules/custom code can reference (ARNs, IDs, names)

---

## How Each Agent Would Use This

### PIA (new agent — uses platform for everything)

```hcl
# pexa-pia-agent/terraform/main.tf
module "runtime"       { source = "...//agent-runtime?ref=v1.0" ... }
module "slack_bot"     { source = "...//agent-slack-bot?ref=v1.0" ... }
module "secrets"       { source = "...//agent-secrets?ref=v1.0" ... }
module "observability" { source = "...//agent-observability?ref=v1.0" ... }
module "kb"            { source = "...//agent-bedrock-kb?ref=v1.0" ... }
module "memory"        { source = "...//agent-memory?ref=v1.0" ... }
module "gateway"       { source = "...//agent-gateway?ref=v1.0"
  instructions = "PIA tools: Prisma AIRS MCP for security enrichment."
}

# PIA custom: ChatGPT Enterprise connector (expose agent via API for GPT access)
# All PEXArians have ChatGPT Enterprise — PIA can be a custom GPT action
resource "aws_apigatewayv2_api" "chatgpt_connector" { ... }
resource "aws_lambda_function" "chatgpt_invoker" { ... }
```

### Lex (existing — migrate incrementally)

```hcl
# pexa-one-data-compliance-agent/terraform/main.tf
module "runtime"       { source = "...//agent-runtime?ref=v1.0" ... }
module "slack_bot"     { source = "...//agent-slack-bot?ref=v1.0"; desired_count = 2 ... }
module "secrets"       { source = "...//agent-secrets?ref=v1.0" ... }
module "observability" { source = "...//agent-observability?ref=v1.0" ... }

# Lex custom: Bedrock Guardrail (not a shared module — Lex-specific)
resource "aws_bedrock_guardrail" "compliance" { ... }

# KB was pre-created manually — just pass the ID
# No agent-bedrock-kb module needed
```

### Vulnerability Agent (complex — lots of custom)

```hcl
# pexa-one-data-vulnerability-agent/terraform/main.tf
module "runtime"       { source = "...//agent-runtime?ref=v1.0"
  additional_iam_statements = [
    { sid = "Memory", actions = ["bedrock-agentcore:CreateEvent", ...] },
    { sid = "Gateway", actions = ["bedrock-agentcore:InvokeGateway", ...] },
  ]
}
module "slack_bot"     { source = "...//agent-slack-bot?ref=v1.0" ... }
module "secrets"       { source = "...//agent-secrets?ref=v1.0"
  secrets = { "nucleus" = { ... }, "cortex-xdr" = { ... }, "github-app" = { ... } }
  existing_secret_arns = { "slack" = "arn:aws:secretsmanager:..." }
}
module "observability" { source = "...//agent-observability?ref=v1.0" ... }
module "memory"        { source = "...//agent-memory?ref=v1.0" ... }
module "scheduler"     { source = "...//agent-scheduler?ref=v1.0" ... }
module "gateway"       { source = "...//agent-gateway?ref=v1.0"
  instructions = "Vulnerability tools: Nucleus, Slack, Jira."
}

# Vuln custom: Gateway targets (registered via deploy_gateway.py)
# Vuln custom: Cedar policies (agent-specific business rules)
```

### Future Team X (hypothetical — non-Slack, API-only agent)

```hcl
# some-team/their-agent/terraform/main.tf
module "runtime"       { source = "...//agent-runtime?ref=v1.0" ... }
module "secrets"       { source = "...//agent-secrets?ref=v1.0" ... }
module "observability" { source = "...//agent-observability?ref=v1.0" ... }

# No slack_bot — this agent is invoked via API Gateway
# Custom: API Gateway + Lambda proxy (team-owned)
resource "aws_apigatewayv2_api" "agent" { ... }
resource "aws_lambda_function" "invoker" { ... }
```

---

## Directory Layout (in this repo)

```
terraform/modules/
├── agent-runtime/
│   ├── main.tf          # awscc_bedrockagentcore_runtime, ECR, SG, IAM, logs
│   ├── variables.tf     # agent_name, environment, container_image, vpc_id, subnets, additional_*
│   ├── outputs.tf       # runtime_arn, ecr_repo_url, sg_id, role_arn
│   └── README.md        # Usage examples
├── agent-slack-bot/
│   ├── main.tf          # ECS cluster, service, task def, ECR, SG, IAM, logs
│   ├── variables.tf     # agent_name, environment, runtime_arn, secret_arns, vpc_id, subnets, additional_*
│   ├── outputs.tf       # ecr_repo_url, cluster_arn, service_name
│   └── README.md
├── agent-secrets/
│   ├── main.tf          # Secrets Manager resources
│   ├── variables.tf     # agent_name, environment, secrets map, existing_secret_arns map
│   ├── outputs.tf       # secret_arns map (both created and existing, unified)
│   └── README.md
├── agent-observability/
│   ├── main.tf          # Dashboard, alarms, SNS
│   ├── variables.tf     # agent_name, environment, ecs_*, custom_metric_namespace, additional_*
│   ├── outputs.tf       # dashboard_arn, sns_topic_arn
│   └── README.md
├── agent-bedrock-kb/
│   ├── main.tf          # S3, AOSS collection, Bedrock KB + data source
│   ├── variables.tf     # agent_name, environment, existing_s3_bucket_arn, existing_aoss_*, chunking_*
│   ├── outputs.tf       # kb_id, data_source_id, s3_bucket_arn, aoss_collection_arn
│   └── README.md
├── agent-gateway/
│   ├── main.tf          # awscc_bedrockagentcore_gateway, IAM role
│   ├── variables.tf     # agent_name, environment, instructions, authorizer_type, additional_*
│   ├── outputs.tf       # gateway_arn, gateway_id
│   └── README.md
├── agent-memory/
│   ├── main.tf          # awscc_bedrockagentcore_memory
│   ├── variables.tf     # agent_name, environment, strategies, expiry
│   ├── outputs.tf       # memory_id
│   └── README.md
└── agent-scheduler/
    ├── main.tf          # Lambda + EventBridge schedule
    ├── variables.tf     # agent_name, environment, runtime_arn, schedule, payload
    ├── outputs.tf       # schedule_arn, lambda_arn
    └── README.md
```

---

## Acceptance Criteria

1. All 7 modules pass `terraform validate` independently
2. PIA agent can compose runtime + slack_bot + secrets + observability + kb + memory with zero custom TF — just variable values
3. Vuln agent can compose runtime + slack_bot + secrets + observability + memory + scheduler and add custom gateway resources alongside
4. `additional_iam_statements` correctly merges into the runtime role without overriding base permissions
5. Modules are independently plannable (no implicit cross-module dependencies)
6. Pinning to a Git ref (`?ref=v1.0.0`) produces deterministic plans across agent repos
7. A new team can go from zero to a working agent infrastructure by copying an example `main.tf` and filling in variables
8. Security guardrails (egress-only SG, scan-on-push, no public endpoints, log retention) cannot be accidentally disabled
9. Breaking changes (variable renames, resource recreation) require a major version bump
10. Each module has a README with usage example, variable reference, and outputs

## Out of Scope

- Migrating Lex or vuln-agent to use these modules (separate tickets)
- Slack app registration (manual step in api.slack.com)
- Real secret values (injected post-deploy)
- ChatGPT Enterprise custom GPT action setup (PIA will expose via API Gateway — the connector is agent-specific custom TF, not a shared module)
- Prisma AIRS MCP target registration (done via gateway deploy script, not TF — until awscc supports GatewayTarget)
- Cedar policy management (deployed via Python scripts, not TF)
- Cross-region DR
- Cost allocation tags at account level

---

*Generated by kspec-spec on 2026-08-13. Source: DD-6600. Revised after analysis of existing Lex and Vulnerability Agent Terraform.*
