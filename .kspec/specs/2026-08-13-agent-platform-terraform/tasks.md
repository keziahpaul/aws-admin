# Implementation Tasks: Agent Platform Terraform Modules

**Spec**: DD-6600
**Branch**: `feature/DD-6600-agent-platform-terraform`
**PR target**: `develop`
**Generated**: 2026-08-14

---

## Chunk 1: Repo Scaffolding + Versions + Root Terragrunt Config

Establish the directory skeleton, provider versions, and Terragrunt wiring so every subsequent chunk has a consistent place to land. No real AWS resources yet — just `terraform validate` gates.

- [x] Create `terraform/infrastructure/agent-platform/versions.tf` declaring `required_version = ">= 1.0"` and AWS provider `~> 5.0`. No AWSCC provider needed — all AgentCore resources (`aws_bedrockagentcore_*`) are now in the native AWS provider.
- [x] Create `terraform/infrastructure/agent-platform/terragrunt.hcl` that includes the root `find_in_parent_folders()` — mirrors the `privatelink` and `rds-dns-resolver` pattern
- [x] Create empty stub files `main.tf`, `variables.tf`, `outputs.tf` with a placeholder comment so `terraform validate` passes
- [x] Create `terraform/infrastructure/agent-platform/environments/datanp/dev/terragrunt.hcl` with correct S3 remote state bucket (`remote-tfstate-ap-southeast-2-042775015153`), key `infrastructure/agent-platform/datanp/dev/terraform.tfstate`, and workspace prefix `onedata` — matches privatelink/dev pattern
- [x] Create `terraform/infrastructure/agent-platform/environments/datanp/tst/terragrunt.hcl` (same structure, `tst` key)
- [x] **Validate gate**: `terraform init -backend=false && terraform validate` passes in `terraform/infrastructure/agent-platform/`

---

## Chunk 2: Module Scaffold — All 6 Sub-modules

Create the file structure for every sub-module with stubs. Validates that all modules are syntactically correct before any real resources are added. Pure scaffolding — no AWS resources created.

- [x] Create `terraform/infrastructure/agent-platform/modules/iam/` with `main.tf` (stub), `variables.tf` (all variables declared with types: `agent_name`, `environment`, `aws_region`, `account_id`, `kb_bucket_arn`, `opensearch_collection_arn`, `secret_arns` list, `additional_iam_statements`, `tags`), `outputs.tf` stubs
- [x] Create `terraform/infrastructure/agent-platform/modules/s3-kb-bucket/` with `main.tf` (stub), `variables.tf` (`agent_name`, `environment`, `project`, `tags`), `outputs.tf` (`bucket_name`, `bucket_arn`, `bucket_id`)
- [x] Create `terraform/infrastructure/agent-platform/modules/secrets/` with `main.tf` (stub), `variables.tf` (`agent_name`, `environment`, `secrets` map object, `existing_secret_arns` map, `tags`), `outputs.tf` (`secret_arns`, `secret_arns_list`)
- [x] Create `terraform/infrastructure/agent-platform/modules/bedrock-kb/` with `main.tf` (stub), `variables.tf` (all variables from design: `agent_name`, `environment`, `kb_bucket_arn`, `kb_bucket_name`, `kb_s3_prefix`, `embedding_model_arn`, `opensearch_collection_arn`, `opensearch_collection_endpoint`, `bedrock_kb_role_arn`, `chunking_strategy`, `chunk_size`, `overlap_percentage`, `tags`), `outputs.tf` (`knowledge_base_id`, `knowledge_base_arn`, `data_source_id`)
- [x] Create `terraform/infrastructure/agent-platform/modules/ecs-service/` with `main.tf` (stub), `variables.tf` (all variables from design including `use_fargate_spot` bool, `secret_arns` map, `kb_knowledge_base_id`, `create_alb_target_group` bool defaulting to `false`, `create_ecr_repository` bool), `outputs.tf` (`cluster_name`, `cluster_arn`, `service_name`, `service_arn`, `ecr_repository_url`, `security_group_id`)
- [x] Create `terraform/infrastructure/agent-platform/modules/observability/` with `main.tf` (stub), `variables.tf` (`agent_name`, `environment`, `ecs_cluster_name`, `ecs_service_name`, `custom_metric_namespace` optional, `alarm_sns_emails`, `error_rate_threshold`, `latency_p99_threshold`, `tags`), `outputs.tf` (`sns_topic_arn`, `dashboard_name`, `alarm_arns` map)
- [x] Create `terraform/infrastructure/agent-platform/modules/agent-runtime/` with `main.tf` (stub), `variables.tf` (all variables), `outputs.tf` (`runtime_arn`, `runtime_id`, `runtime_endpoint_arn`, `ecr_repository_url`, `security_group_id`, `log_group_arn`)
- [x] Create `terraform/infrastructure/agent-platform/modules/agent-memory/` with `main.tf` (stub), `variables.tf` (all variables), `outputs.tf` (`memory_id`, `memory_arn`)
- [x] Create `terraform/infrastructure/agent-platform/modules/agent-gateway/` with `main.tf` (stub), `variables.tf` (all variables), `outputs.tf` (`gateway_arn`, `gateway_id`, `gateway_role_arn`)
- [x] Create `terraform/infrastructure/agent-platform/modules/agent-scheduler/` with `main.tf` (stub), `variables.tf` (all variables), `outputs.tf` (`schedule_arn`, `lambda_function_arn`)
- [x] **Validate gate**: `terraform init -plugin-dir=<root .terraform/providers> && terraform validate` passes in each of the 10 module directories (10/10 PASS — disk full workaround: used -plugin-dir to reuse existing provider binary)

---

## Chunk 3: Module Implementation — `iam` + `s3-kb-bucket`

Implement the two foundational modules that have no dependencies on other modules (Phase 1 in the dependency graph). These are the first real AWS resources.

- [x] Implement `modules/iam/main.tf` with three IAM roles:
  - `aws_iam_role.task_execution` (trust: `ecs-tasks.amazonaws.com`) + `AmazonECSTaskExecutionRolePolicy` managed policy attachment + inline policy for scoped `secretsmanager:GetSecretValue` on `var.secret_arns` and `logs:CreateLogStream`/`PutLogEvents` scoped to `/ecs/${var.environment}-${var.agent_name}*`
  - `aws_iam_role.task_role` (trust: `ecs-tasks.amazonaws.com`) + inline policy: Bedrock invoke (`bedrock:InvokeModel`, `bedrock:InvokeModelWithResponseStream`, `bedrock:Converse`, `bedrock:ConverseStream`, `bedrock:GetInferenceProfile`), KB retrieve (`bedrock:Retrieve`, `bedrock:RetrieveAndGenerate`), S3 read scoped to `var.kb_bucket_arn`, `cloudwatch:PutMetricData` with namespace condition, VPC networking permissions matching the vuln-agent pattern (`ec2:CreateNetworkInterface`, `DescribeNetworkInterfaces`, `DeleteNetworkInterface`, `DescribeSubnets`, `DescribeSecurityGroups`, `DescribeVpcs`)
  - `aws_iam_role.bedrock_kb` (trust: `bedrock.amazonaws.com` with `aws:SourceAccount` + `aws:SourceArn` conditions to prevent confused deputy) + inline policy for S3 read, `bedrock:InvokeModel` on Titan Embed V2 ARN, `aoss:APIAccessAll` on `var.opensearch_collection_arn`
  - All roles tagged with `var.tags`; role names follow `${var.environment}-${var.agent_name}-*` convention
- [x] Implement `modules/s3-kb-bucket/main.tf`: `aws_s3_bucket`, `aws_s3_bucket_versioning` (Enabled), `aws_s3_bucket_server_side_encryption_configuration` (AES256 — NOT KMS, per design decision: allows Bedrock service principal access without KMS key policy complexity), `aws_s3_bucket_public_access_block` (all four blocks true), `aws_s3_bucket_lifecycle_configuration` (90-day Standard-IA transition, 180-day noncurrent version expiry), `aws_s3_bucket_policy` granting `bedrock.amazonaws.com` read with `aws:SourceAccount` condition. Bucket name: `${var.environment}-${var.agent_name}-kb-documents-${data.aws_caller_identity.current.account_id}`
- [ ] **Validate gate**: `terraform init -backend=false && terraform validate` passes in both modules independently
- [ ] **Plan test**: `terraform plan -var="agent_name=pia" -var="environment=dev" ...` (with required vars) produces expected resource list with no errors for each module

---

## Chunk 4: Module Implementation — `secrets`

Implement the secrets module with flexible entry management. Has no dependencies on other modules; its outputs feed `iam` and `ecs-service`.

- [x] Implement `modules/secrets/main.tf`:
  - `aws_secretsmanager_secret` using `for_each` over `var.secrets` map — secret name: `${var.environment}/${var.agent_name}/${each.key}`, `recovery_window_in_days = 7`, tags include `SecretType = each.key`
  - `aws_secretsmanager_secret_version` for each created secret with `secret_string = jsonencode({ value = "PLACEHOLDER-replace-before-starting-service" })` and `lifecycle { ignore_changes = [secret_string] }` — matches vuln-agent and Lex pattern exactly
  - `data "aws_secretsmanager_secret"` for each entry in `var.existing_secret_arns` map (BYO secrets — reference existing, create nothing)
  - Update `variables.tf`: `secrets` is `map(object({ description = optional(string, "") }))` defaulting to `{}`, `existing_secret_arns` is `map(string)` defaulting to `{}`
  - `outputs.tf`: `secret_arns` = merged map of created secret ARNs + existing secret ARNs (unified interface for consumers), `secret_arns_list` = flattened list of all ARNs for use in IAM resource arrays
- [ ] **Validate gate**: `terraform init -backend=false && terraform validate` passes
- [ ] **Behaviour test** (plan only): With `secrets = { "slack-bot" = { description = "Slack tokens" } }` plan shows 1 `aws_secretsmanager_secret` + 1 `aws_secretsmanager_secret_version`; with `existing_secret_arns = { "slack" = "arn:aws:..." }` plan shows 0 resources to create (data source only)

---

## Chunk 5: Module Implementation — `bedrock-kb`

Implement the Bedrock Knowledge Base module. Depends on `s3-kb-bucket` (bucket ARN) and `iam` (KB role ARN). This is the most complex module due to per-agent AOSS data access policy scoping.

- [x] Implement `modules/bedrock-kb/main.tf`:
  - `aws_opensearchserverless_access_policy` (type `data`) granting `var.bedrock_kb_role_arn` index-level permissions (`aoss:CreateIndex`, `aoss:DeleteIndex`, `aoss:UpdateIndex`, `aoss:DescribeIndex`, `aoss:ReadDocument`, `aoss:WriteDocument`) on the agent's index `index/${var.environment}-agent-platform-kb/${var.environment}-${var.agent_name}-index`, plus collection-level `aoss:DescribeCollectionItems`
  - `aws_bedrockagent_knowledge_base` with `VECTOR` type, `OPENSEARCH_SERVERLESS` storage, field mapping (`embedding`, `text`, `metadata`), `depends_on = [aws_opensearchserverless_access_policy.bedrock_kb]`
  - `aws_bedrockagent_data_source` with S3 config pointing to `var.kb_bucket_arn`, `RETAIN` data deletion policy, `FIXED_SIZE` chunking (512 tokens, 20% overlap) as overridable default
- [ ] **Validate gate**: `terraform init -backend=false && terraform validate` passes
- [ ] Document in module README: index name convention is `${var.environment}-${var.agent_name}-index`, guaranteed unique by construction across all agents in the shared collection

---

## Chunk 6: Module Implementation — `ecs-service`

Implement the ECS Fargate service module. Depends on `iam` (role ARNs), `secrets` (secret ARNs map), and `bedrock-kb` (KB ID for environment variable injection).

- [x] Implement `modules/ecs-service/main.tf`:
  - `aws_ecs_cluster` with `containerInsights = enabled`
  - `aws_ecs_cluster_capacity_providers` — `FARGATE` always; adds `FARGATE_SPOT` when `var.use_fargate_spot = true`, with `FARGATE_SPOT` as default capacity provider in that case
  - Two `aws_cloudwatch_log_group` resources: `/ecs/${var.environment}-${var.agent_name}/runtime` and `/ecs/${var.environment}-${var.agent_name}/slack-bot`, both with `var.log_retention_days` (default `14` — the NF6 minimum)
  - `aws_security_group` for ECS tasks — **egress-only** (`protocol = "-1"`, `cidr_blocks = ["0.0.0.0/0"]`), no ingress rules. Slack bot uses Socket Mode (outbound WebSocket only); runtime is invoked by AgentCore control plane via VPC networking, not inbound HTTP. This matches the vuln-agent and Lex SG patterns.
  - `aws_ecs_task_definition` with two containers: `runtime` (port 8080, essential, uses `awslogs` log driver, secrets injected from `var.secret_arns` map, env vars include `ENVIRONMENT`, `KB_KNOWLEDGE_BASE_ID`, `AWS_REGION`) and `slack-bot` (no port mapping, essential, `awslogs` log driver, secrets from `var.secret_arns`)
  - `aws_ecs_service` with `network_configuration { assign_public_ip = false }`, `capacity_provider_strategy`, rolling deploy (`deployment_minimum_healthy_percent = 50`, `deployment_maximum_percent = 200`), `lifecycle { ignore_changes = [desired_count, task_definition] }`, `enable_ecs_managed_tags = true`
  - `aws_appautoscaling_target` + `aws_appautoscaling_policy` (CPU target tracking at 70%, scale-in cooldown 300s, scale-out 60s)
  - ALB target group resources are gated behind `var.create_alb_target_group` (default `false`) so Slack Socket Mode agents don't require an ALB
- [x] **Validate gate**: `terraform init -backend=false && terraform validate` passes
- [x] Confirm no public IP assignment is possible — `assign_public_ip = false` is hardcoded (NF4)

---

## Chunk 7: Module Implementation — `observability`

Implement the observability module. Depends on `ecs-service` (cluster/service names) and `bedrock-kb` (KB ID for the retrieval latency widget).

- [x] Implement `modules/observability/main.tf`:
  - `aws_sns_topic` named `${var.environment}-${var.agent_name}-alarms` + `aws_sns_topic_subscription` for each email in `var.alarm_sns_emails` (using `count`)
  - Derive `local.metric_namespace` as `coalesce(var.custom_metric_namespace, "${upper(var.agent_name)}/Agent")` so teams can override (e.g., `"PIA/Agent"`, `"Lex/Compliance"`)
  - Three `aws_cloudwatch_metric_alarm` resources:
    - Error rate: `${local.metric_namespace}` ErrorCount > 5 over 5 minutes, `treat_missing_data = "notBreaching"`
    - P99 latency: `${local.metric_namespace}` ResponseLatency `extended_statistic = "p99"` > 30000ms, `treat_missing_data = "notBreaching"`
    - ECS unhealthy tasks: `AWS/ECS` RunningTaskCount < 1 (dimension: cluster + service name), `treat_missing_data = "breaching"`
  - `aws_cloudwatch_dashboard` with 5 widgets: Invocation Count, Response Latency (P50/P95/P99), Error Rate, KB Retrieval Latency (`AWS/Bedrock KnowledgeBaseRetrieveAndGenerateLatency`), ECS Running Task Count
- [x] **Validate gate**: `terraform init -backend=false && terraform validate` passes

---

## Chunk 8: Composition Root + Shared OpenSearch + `for_each` Wiring

Wire all 6 modules together in the composition root. This is where the `for_each` pattern over `var.agents` connects everything. Also adds the shared OpenSearch Serverless collection that sits above all per-agent modules.

- [ ] Implement `terraform/infrastructure/agent-platform/main.tf`:
  - `data "aws_caller_identity"` + `data "aws_region"`
  - `locals` block: `common_tags` map and `agents_map = { for a in var.agents : a.name => a }`
  - Shared OpenSearch Serverless resources (all conditional on `var.create_opensearch_collection`): `aws_opensearchserverless_collection` (type `VECTORSEARCH`), `aws_opensearchserverless_security_policy` encryption (`AWSOwnedKey = true`), `aws_opensearchserverless_security_policy` network (`AllowFromPublic = false`)
  - `locals.opensearch_collection_arn` and `locals.opensearch_collection_endpoint` derived from the conditional collection resource
  - Module instantiation in dependency order:
    - Phase 1 (no deps): `module "s3_kb_bucket"` with `for_each = local.agents_map`, `module "secrets"` with `for_each = local.agents_map`
    - Phase 2: `module "iam"` with `for_each`, `depends_on = [module.s3_kb_bucket, module.secrets]`
    - Phase 3: `module "bedrock_kb"` with `for_each`, `depends_on = [module.iam, module.s3_kb_bucket]`; `module "ecs_service"` with `for_each`, `depends_on = [module.iam, module.secrets]`
    - Phase 4: `module "observability"` with `for_each`, `depends_on = [module.ecs_service, module.bedrock_kb]`
  - Each module call merges `common_tags` with agent-specific tags: `merge(local.common_tags, each.value.tags, { agent_name = each.key })`
- [ ] Implement `terraform/infrastructure/agent-platform/variables.tf` — full variable set: `aws_region`, `environment`, `project`, `cost_centre`, `vpc_id`, `private_subnet_ids`, `use_fargate_spot` (default `false`), `agents` list of objects with `optional()` fields, `shared_opensearch_collection_name` (default `"agent-platform-kb"`), `create_opensearch_collection` (default `true`)
- [ ] Implement `terraform/infrastructure/agent-platform/outputs.tf` — per-agent output map keyed by agent name (cluster name, service name, KB ID, bucket name, secret ARNs, dashboard name), plus `opensearch_collection_arn` at root level
- [ ] **Validate gate**: `terraform init -backend=false && terraform validate` passes at the composition root

---

## Chunk 9: Environment tfvars — datanp (dev + tst)

Create the PIA agent configuration for datanp dev and tst. These are the first plannable environments. Placeholder image URIs are acceptable — the plan validates all resource configuration without requiring real ECR images deployed.

- [ ] Create `environments/datanp/dev/pia.auto.tfvars` with:
  - `vpc_id` and `private_subnet_ids` — look up from the datanp data VPC (cross-reference with existing vuln-agent `environments/datanp/dev/` tfvars or run `aws ec2 describe-vpcs --filters "Name=tag:Name,Values=data-vpc" --profile datanp`)
  - `use_fargate_spot = true` (non-prod cost saving)
  - `create_opensearch_collection = true`, `shared_opensearch_collection_name = "agent-platform-kb"`
  - `agents` list with single `pia` entry: placeholder image URIs `042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/pia-agent-runtime:latest` etc., `runtime_cpu = 1024`, `runtime_memory = 2048`, `slack_bot_cpu = 512`, `slack_bot_memory = 1024`, `alarm_sns_emails = ["platform-alerts-dev@pexa.com.au"]`
- [ ] Create `environments/datanp/tst/pia.auto.tfvars` — same structure as dev, update `alarm_sns_emails` to `["platform-alerts-tst@pexa.com.au"]`
- [ ] **Validate gate**: `terragrunt validate` passes in both `environments/datanp/dev` and `environments/datanp/tst`
- [ ] **Plan test** (requires datanp AWS creds via OIDC or profile): `terragrunt plan` in `environments/datanp/dev` produces a clean plan. Verify: all resource names follow `dev-pia-*` pattern, OpenSearch collection created once (not per agent), no errors.

---

## Chunk 10: Environment tfvars — dataprd (pst + prd) + GitHub Actions Account Config

Create the production environment configurations and the accounts JSON consumed by the GitHub Actions caller workflow.

- [ ] Create `environments/dataprd/pst/terragrunt.hcl` with S3 remote state config, key `infrastructure/agent-platform/dataprd/pst/terraform.tfstate`, bucket using dataprd account remote state bucket ARN
- [ ] Create `environments/dataprd/prd/terragrunt.hcl` — same pattern, key `prd`
- [ ] Create `environments/dataprd/pst/pia.auto.tfvars` — `use_fargate_spot = false`, on-demand Fargate, production-tagged image URIs (semver placeholder or `:pst`), `alarm_sns_emails = ["platform-alerts-pst@pexa.com.au"]`
- [ ] Create `environments/dataprd/prd/pia.auto.tfvars` — `use_fargate_spot = false`, `runtime_cpu = 2048`, `runtime_memory = 4096` for production, `alarm_sns_emails = ["platform-alerts-prd@pexa.com.au", "oncall@pexa.com.au"]`
- [ ] Create `.github/config/agent-platform-accounts.json` matching the structure of `data-ingestion-accounts.json` — keys `datanp` (`account_id: "042775015153"`, `runner_type: "non-prod"`, `environments: ["dev", "tst"]`) and `dataprd` (`account_id: "DATAPRD_ACCOUNT_ID"` placeholder, `runner_type: "prod"`, `environments: ["pst", "prd"]`). Add metadata block with `purpose`, `deployment_tool: "terragrunt"`, `iam_role: "GitHubRunnerAgentPlatformDeploymentRole"`.

---

## Chunk 11: GitHub Actions Workflows

Add the reusable deployment workflow and the agent-platform caller workflow. Must strictly follow the `structure.md` patterns: caller+reusable split, no matrix strategy, explicit per-env jobs with `if:` branch guards.

- [ ] Create `.github/workflows/reusable-agent-platform-deploy.yml`:
  - `workflow_call` inputs: `environment`, `runner-type`, `aws-account`, `terragrunt-path`, `no-execute-changeset` (bool)
  - Single job `deploy` running on `['${{ inputs.runner-type }}', 'deploy']`
  - Container: `004761221582.dkr.ecr.ap-southeast-2.amazonaws.com/apim-kong-provisioning:latest` with SSH volume mounts (matches all existing reusable workflows in this repo)
  - Steps with emoji prefixes matching repo style: checkout → `configure-aws-credentials@v4` assuming `arn:aws:iam::${{ inputs.aws-account }}:role/GitHubRunnerAgentPlatformDeploymentRole` → `terragrunt init` → `terragrunt validate` → `terragrunt plan -detailed-exitcode -out=tfplan` (capture exit code, fail on 1) → `terragrunt apply tfplan` (only when plan exit code = 2 AND `!inputs.no-execute-changeset`) → cleanup `.terragrunt-cache`
  - Outputs: `plan-exitcode`, `deployment-status`
- [ ] Create `.github/workflows/deploy-agent-platform.yml` (caller):
  - Triggers: `push` on `feature/*`, `develop`, `main`, `release/*` + `workflow_dispatch` with `no-execute-changeset` input
  - `validate` job reads `.github/config/agent-platform-accounts.json` via `jq`, outputs `datanp-account-id` and `dataprd-account-id`
  - **Four separate jobs** (NEVER matrix — per structure.md CRITICAL rule):
    - `deploy-dev`: `if: startsWith(github.ref_name, 'feature/')`, account datanp, path `environments/datanp/dev`
    - `deploy-tst`: `if: github.ref_name == 'develop'`, account datanp, path `environments/datanp/tst`
    - `deploy-pst`: `if: github.ref_name == 'main' || startsWith(github.ref_name, 'release/')`, account dataprd, path `environments/dataprd/pst`
    - `deploy-prd`: `needs: [validate, deploy-pst]`, same branch condition as pst, account dataprd, path `environments/dataprd/prd`
- [ ] **Validate gate**: `yamllint` passes on both workflow files; manually confirm no `matrix:` key exists in either file

---

## Chunk 12: GitHub Runner IAM Role (Terraform)

The GitHub Actions workflows need a dedicated deployment role in each AWS account. Provisioned as Terraform so it is auditable and reproducible.

- [ ] Create `terraform/infrastructure/agent-platform-iam/main.tf` with `aws_iam_role` named `GitHubRunnerAgentPlatformDeploymentRole`:
  - Trust policy: `token.actions.githubusercontent.com` OIDC principal, condition `StringLike sub = "repo:PEXA-AU/pexa-one-data-aws-admin:*"`
  - Inline policy with least-privilege scoped permissions: ECS CRUD, ECR CRUD, IAM role/policy CRUD path-scoped to `/${var.environment}-*-agent*` (prevents privilege escalation to unrelated roles), Bedrock KB + AOSS, S3 CRUD scoped to `*-kb-documents-*` bucket pattern, Secrets Manager CRUD scoped to `${var.environment}/*`, CloudWatch/SNS/Logs, AppAutoScaling, EC2 security group management (`CreateSecurityGroup`, `AuthorizeSecurityGroup*`, `DeleteSecurityGroup`, `RevokeSecurityGroup*`)
- [ ] Create `terraform/infrastructure/agent-platform-iam/variables.tf` (`environment`, `aws_region`, `project`, `tags`) and `outputs.tf` (`role_arn`, `role_name`)
- [ ] Create `terraform/infrastructure/agent-platform-iam/environments/datanp/dev/terragrunt.hcl` and `datanp/tst/terragrunt.hcl`
- [ ] Write `terraform/infrastructure/agent-platform-iam/README.md` documenting the bootstrap catch-22: this role must be applied once manually using `GitHubRunnerPEXAOneDataRole` (the existing runner role), after which subsequent changes are self-deploying
- [ ] **Validate gate**: `terraform validate` passes

---

## Chunk 13: Module READMEs + Validate Script

Each module needs a README per acceptance criterion 10. A convenience validation script enables one-command local testing.

- [ ] Write `modules/iam/README.md` — purpose, usage example showing how to reference `task_execution_role_arn` and `task_role_arn` outputs, variable reference table, outputs table, note on IAM path scoping
- [ ] Write `modules/s3-kb-bucket/README.md` — purpose, why AES256 not KMS (Bedrock service principal access without KMS policy complexity), lifecycle configuration, Bedrock bucket policy explanation, variable + output tables
- [ ] Write `modules/secrets/README.md` — purpose, `secrets` vs `existing_secret_arns` pattern (BYO secrets), `lifecycle ignore_changes` rationale, usage examples for both create-new and reference-existing patterns, post-deploy secret injection instructions
- [ ] Write `modules/bedrock-kb/README.md` — purpose, shared AOSS collection model and index naming convention (`${env}-${agent}-index`), chunking defaults and how to override, AOSS data access policy scoping, example with variable + output tables
- [ ] Write `modules/ecs-service/README.md` — purpose, two-container model (runtime + slack-bot), why egress-only SG (Socket Mode), Fargate Spot toggle, `create_alb_target_group` opt-in, variable + output tables
- [ ] Write `modules/observability/README.md` — purpose, default vs custom metric namespace, dashboard widget list, alarm thresholds and how to override, SNS email subscription, example
- [ ] Create `terraform/infrastructure/agent-platform/scripts/validate-all.sh` (executable `chmod +x`) — loops over all 6 module dirs + composition root, runs `terraform init -backend=false && terraform validate` in each, prints pass/fail per module, exits non-zero on any failure. This is the required local test gate documented in the PR template.

---

## Chunk 14: End-to-end Plan Test + Documentation

Final integration validation. No new code files — validates everything works together and leaves an operational trail for the next team.

- [ ] Run `scripts/validate-all.sh` locally — all 7 directories must pass. Fix any issues before raising PR.
- [ ] Run `terragrunt plan` against `environments/datanp/dev` with real datanp AWS credentials. Verify: clean plan (no errors), resource names follow `dev-pia-*` convention, OpenSearch collection created once at root (not inside each agent module), `Plan: N to add, 0 to change, 0 to destroy` on first run.
- [ ] Create `terraform/infrastructure/agent-platform/POST_DEPLOY.md` with post-apply runbook: (1) inject real Slack bot token + app token into `${environment}/${agent}/slack-bot` secret, (2) trigger initial KB data source sync (`aws bedrock-agent start-ingestion-job`), (3) verify ECS tasks reach `RUNNING` status, (4) test KB retrieval (`aws bedrock-agent-runtime retrieve`), (5) confirm CloudWatch dashboard renders
- [ ] Create `terraform/infrastructure/agent-platform/ADDING_A_NEW_AGENT.md` — step-by-step for teams: copy `environments/datanp/dev/pia.auto.tfvars`, add entry to `agents` list with new agent's name + images, set `create_opensearch_collection = false` and provide `existing_opensearch_collection_arn` (second agent onwards shares the collection), create caller workflow by copying `deploy-agent-platform.yml` and updating the `terragrunt-path` values
- [ ] Raise PR `feature/DD-6600-agent-platform-terraform` → `develop` with `validate-all.sh` output attached as a PR comment and plan output summary from datanp/dev

---

---

## Chunk 15: Module Implementation — `agent-runtime` (AgentCore Runtime)

The core runtime module. Creates the AgentCore managed runtime that hosts the agent container. Uses the **native AWS provider** (`aws_bedrockagentcore_agent_runtime`), NOT the AWSCC provider — aligns with PIDP's existing agentcore module and avoids a second provider dependency.

- [x] Create `terraform/infrastructure/agent-platform/modules/agent-runtime/` with `main.tf`, `variables.tf`, `outputs.tf`, `README.md`
- [x] Implement `modules/agent-runtime/main.tf`:
  - `aws_ecr_repository` for the agent runtime image with `image_scanning_configuration { scan_on_push = true }`, `image_tag_mutability = "MUTABLE"`, lifecycle policy (expire untagged after 1 day, keep max 10 images) — matches Lex/Vuln ECR patterns exactly
  - `aws_security_group` — egress-only (HTTPS 443 outbound), VPC mode networking for AgentCore. Name: `${var.environment}-${var.agent_name}-agentcore-runtime-sg`
  - `aws_bedrockagentcore_agent_runtime` with:
    - `agent_runtime_name` = `${replace("${var.environment}_${var.agent_name}", "-", "_")}_runtime"` (underscore convention, max 48 chars — matches PIDP pattern)
    - `agent_runtime_artifact { container_configuration { container_uri = var.container_image } }`
    - `network_configuration { network_mode = var.network_mode; network_mode_config { subnets = var.private_subnet_ids; security_groups = [aws_security_group.this.id] } }` (conditional on VPC mode)
    - `role_arn = var.iam_role_arn`
    - `environment_variables = merge(var.base_environment_variables, var.additional_environment_variables)`
    - `protocol_configuration { server_protocol = "HTTP" }`
  - `aws_bedrockagentcore_agent_runtime_endpoint` — creates the invocation endpoint
  - `aws_cloudwatch_log_group` for runtime logs: `/aws/agentcore/${var.environment}-${var.agent_name}`, retention = `var.log_retention_days` (default 14)
- [x] Implement `modules/agent-runtime/variables.tf`:
  - `agent_name`, `environment`, `container_image` (required)
  - `iam_role_arn` (required — the AgentCore runtime role from IAM module)
  - `vpc_id`, `private_subnet_ids` (required for VPC mode)
  - `network_mode` (default `"VPC"`, validation: `["VPC", "PUBLIC"]`)
  - `base_environment_variables` (map, default `{}`) — standard vars injected by the platform
  - `additional_environment_variables` (map, default `{}`) — team-specific vars merged on top
  - `log_retention_days` (default `14`)
  - `idle_timeout` (default `1800`) — seconds before idle session killed
  - `max_lifetime` (default `3600`) — max session seconds
  - `tags` (map, default `{}`)
- [x] Implement `modules/agent-runtime/outputs.tf`: `runtime_arn`, `runtime_id`, `runtime_endpoint_arn`, `ecr_repository_url`, `security_group_id`, `log_group_arn`
- [x] **Validate gate**: `terraform init -backend=false && terraform validate` passes

---

## Chunk 16: Module Implementation — `agent-memory` (AgentCore Memory)

Creates the AgentCore Memory store for session context and deduplication. Uses native AWS provider (`aws_bedrockagentcore_memory` + `aws_bedrockagentcore_memory_strategy`).

- [x] Create `terraform/infrastructure/agent-platform/modules/agent-memory/` with `main.tf`, `variables.tf`, `outputs.tf`, `README.md`
- [x] Implement `modules/agent-memory/main.tf`:
  - `aws_bedrockagentcore_memory` with:
    - `name` = `${replace("${var.environment}_${var.agent_name}", "-", "_")}_memory"`
    - `description` = `"Memory store for ${var.agent_name} agent"`
    - `event_expiry_duration` = `var.event_expiry_days`
  - `aws_bedrockagentcore_memory_strategy` using `for_each` over `var.memory_strategies`:
    - `memory_id` = `aws_bedrockagentcore_memory.this.id`
    - Strategy type determined by `each.value.type` (semantic or summary)
    - `name` = `each.value.name`
    - `namespace_templates` = `each.value.namespaces`
- [x] Implement `modules/agent-memory/variables.tf`:
  - `agent_name`, `environment` (required)
  - `event_expiry_days` (default `90`)
  - `memory_strategies` — `list(object({ type = string, name = string, namespaces = list(string) }))` default `[]`
  - `tags` (map, default `{}`)
- [x] Implement `modules/agent-memory/outputs.tf`: `memory_id`, `memory_arn`
- [x] **Validate gate**: `terraform init -backend=false && terraform validate` passes

---

## Chunk 17: Module Implementation — `agent-gateway` (AgentCore Gateway)

Creates the AgentCore Gateway for MCP tool access. Uses native AWS provider — and unlike the vuln-agent's Python workaround, `aws_bedrockagentcore_gateway_target` is now a proper TF resource so targets can be declared in HCL too.

- [x] Create `terraform/infrastructure/agent-platform/modules/agent-gateway/` with `main.tf`, `variables.tf`, `outputs.tf`, `README.md`
- [x] Implement `modules/agent-gateway/main.tf`:
  - `aws_iam_role.gateway` with trust policy for `bedrock-agentcore.amazonaws.com`
  - `aws_bedrockagentcore_gateway` with:
    - `name` = `${var.environment}-${var.agent_name}-gateway`
    - `authorizer_type` = `var.authorizer_type` (default `"AWS_IAM"`)
    - `protocol_type` = `"MCP"`
    - `role_arn` = `aws_iam_role.gateway.arn`
    - `protocol_configuration { mcp { instructions = var.instructions } }`
  - `aws_bedrockagentcore_gateway_target` using `for_each` over `var.gateway_targets` (optional — teams can also register targets out-of-band if needed):
    - `gateway_id` = `aws_bedrockagentcore_gateway.this.id`
    - `name`, `type`, `endpoint_configuration` from each target config
- [x] Implement `modules/agent-gateway/variables.tf`:
  - `agent_name`, `environment` (required)
  - `instructions` (string, default `""`) — gateway-level tool description
  - `authorizer_type` (default `"AWS_IAM"`)
  - `gateway_targets` — `list(object({ name = string, description = optional(string, ""), endpoint_type = string, endpoint_uri = string }))` default `[]`
  - `tags` (map, default `{}`)
- [x] Implement `modules/agent-gateway/outputs.tf`: `gateway_arn`, `gateway_id`, `gateway_role_arn`
- [x] **Validate gate**: `terraform init -backend=false && terraform validate` passes

---

## Chunk 18: Module Implementation — `agent-scheduler` (EventBridge + Lambda)

Creates the EventBridge schedule + Lambda proxy for agents that need cron/batch invocations. Matches the vuln-agent's nightly scan pattern but parameterised for reuse.

- [x] Create `terraform/infrastructure/agent-platform/modules/agent-scheduler/` with `main.tf`, `variables.tf`, `outputs.tf`, `README.md`
- [x] Implement `modules/agent-scheduler/main.tf`:
  - `data "archive_file"` for the inline Lambda function (thin proxy that calls `invoke_agent_runtime`)
  - `aws_iam_role.scheduler_lambda` with trust `lambda.amazonaws.com`, inline policy: `bedrock-agentcore:InvokeAgentRuntime` on `var.runtime_arn`, `logs:*` scoped to log group
  - `aws_lambda_function.trigger` — Python 3.12, 60s timeout, env var `AGENT_RUNTIME_ARN`
  - `aws_cloudwatch_log_group` for Lambda: `/aws/lambda/${var.environment}-${var.agent_name}-scheduler`
  - `aws_iam_role.scheduler` with trust `scheduler.amazonaws.com`, inline policy: `lambda:InvokeFunction` on the Lambda ARN
  - `aws_scheduler_schedule` with `var.schedule_expression`, `var.schedule_timezone` (default `"UTC"`), flexible time window OFF, target = Lambda ARN with `var.payload` as input JSON
- [x] Implement `modules/agent-scheduler/variables.tf`:
  - `agent_name`, `environment` (required)
  - `runtime_arn` (required — the AgentCore runtime to invoke)
  - `schedule_expression` (required — e.g., `"cron(0 12 * * ? *)"`)
  - `schedule_timezone` (default `"UTC"`)
  - `payload` (map, default `{}`) — JSON payload sent to the runtime
  - `tags` (map, default `{}`)
- [x] Implement `modules/agent-scheduler/outputs.tf`: `schedule_arn`, `lambda_function_arn`
- [x] **Validate gate**: `terraform init -backend=false && terraform validate` passes

---

## Chunk 19: Fixes — `additional_iam_statements` + Optional Variables + ECR in ECS Module

Address the verification gaps: IAM extensibility, optional KB variable, and ECR repo creation.

- [ ] Add `additional_iam_statements` variable to `modules/iam/variables.tf`:
  ```hcl
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
  ```
  In `main.tf`, use `dynamic "statement"` block inside the task_role inline policy to merge these alongside the base statements.
- [ ] Make `kb_bucket_arn` optional in `modules/iam/variables.tf` (default `""`) — skip KB-related IAM statements when empty. This ensures agents without a KB (vuln-agent) can use the IAM module without providing a dummy value.
- [ ] Make `kb_knowledge_base_id` optional (default `""`) in `modules/ecs-service/variables.tf`. Conditionally inject the `KB_KNOWLEDGE_BASE_ID` environment variable only when non-empty:
  ```hcl
  environment = concat(
    var.base_env_vars,
    var.kb_knowledge_base_id != "" ? [{ name = "KNOWLEDGE_BASE_ID", value = var.kb_knowledge_base_id }] : []
  )
  ```
- [ ] Add `aws_ecr_repository` for the slack bot image in `modules/ecs-service/main.tf` (with scan-on-push, lifecycle policy). Gated behind `var.create_ecr_repository` (default `true`). When `false`, accepts `var.slack_bot_image` as a pre-existing URI.
- [ ] Remove `alb_listener_arn` as a required root variable. Make all ALB-related resources conditional on `var.create_alb_target_group` (already defaulting to `false`). Socket Mode agents (the default) get no ALB resources.
- [ ] **Validate gate**: All modules still pass `terraform validate` after changes

---

## Chunk 20: Versioning Strategy + CHANGELOG

Address acceptance criterion 9: breaking changes require major version bump.

- [ ] Create `terraform/infrastructure/agent-platform/VERSIONING.md` documenting:
  - Semver: MAJOR.MINOR.PATCH
  - MAJOR bump: variable renames, resource recreations, removed outputs
  - MINOR bump: new optional variables, new modules, new outputs
  - PATCH bump: bug fixes, documentation
  - Tagging convention: `agent-platform/v1.0.0` (prefixed to avoid conflicts with other tags in the monorepo)
  - Consumer pinning: `?ref=agent-platform/v1.0.0`
- [ ] Create `terraform/infrastructure/agent-platform/CHANGELOG.md` with initial `## [1.0.0] - Unreleased` section listing all modules
- [ ] Add a task note to Chunk 14: after PR merge and validation, create git tag `agent-platform/v1.0.0`

---

## Summary (Revised)

| Chunk | Description | New Files | Reviewable Gate |
|-------|-------------|-----------|-----------------|
| 1 | Scaffolding + Terragrunt wiring | ~7 | `terraform validate` passes |
| 2 | Module stubs (all 10 modules) | ~30 | All modules validate |
| 3 | `iam` + `s3-kb-bucket` impl | 2 modules | Plan shows IAM roles + S3 bucket |
| 4 | `secrets` impl | 1 module | Plan shows secrets + data sources |
| 5 | `bedrock-kb` impl | 1 module | Plan shows KB + AOSS access policy |
| 6 | `ecs-service` impl | 1 module | Plan shows ECS cluster + task def + SG |
| 7 | `observability` impl | 1 module | Plan shows dashboard + alarms |
| 8 | Composition root wiring | 3 files | `terraform validate` at root |
| 9 | datanp tfvars + plan test | 2 tfvars | Clean `terragrunt plan` on datanp/dev |
| 10 | dataprd tfvars + accounts JSON | 5 files | JSON validated by `jq` |
| 11 | GitHub Actions workflows | 2 workflows | YAML lint passes, no matrix |
| 12 | GitHub Runner IAM role TF | ~4 files | `terraform validate` passes |
| 13 | READMEs + validate script | 11 files | `validate-all.sh` exits 0 |
| 14 | E2E plan test + runbooks | 2 docs + PR | PR raised, plan output attached |
| **15** | **`agent-runtime` impl (AgentCore)** | **1 module** | **Plan shows runtime + ECR + endpoint** |
| **16** | **`agent-memory` impl** | **1 module** | **Plan shows memory + strategies** |
| **17** | **`agent-gateway` impl** | **1 module** | **Plan shows gateway + targets** |
| **18** | **`agent-scheduler` impl** | **1 module** | **Plan shows Lambda + EventBridge** |
| **19** | **Fixes: IAM extensibility + optional vars + ECR** | **Updates to 3 modules** | **All modules still validate** |
| **20** | **Versioning strategy + CHANGELOG** | **2 docs** | **Tag created post-merge** |

**Total**: ~80 files across 20 chunks. Provider: `hashicorp/aws` only (no AWSCC needed).

---

## Key Corrections from Verification

| Issue | Resolution |
|-------|-----------|
| AWSCC provider | **Removed.** All AgentCore resources use native `aws` provider (`aws_bedrockagentcore_*`) |
| `agent-runtime` missing | Added as Chunk 15 |
| `agent-memory` missing | Added as Chunk 16 |
| `agent-gateway` missing | Added as Chunk 17 |
| `agent-scheduler` missing | Added as Chunk 18 |
| `additional_iam_statements` missing | Added in Chunk 19 |
| `kb_knowledge_base_id` required | Made optional in Chunk 19 |
| ALB required | Made fully optional in Chunk 19 |
| ECR repos not created | Added to `ecs-service` + `agent-runtime` modules |
| No versioning task | Added as Chunk 20 |
| Gateway targets need Python script | **No longer true** — `aws_bedrockagentcore_gateway_target` exists in native provider |

---

## Dependency Graph (Revised)

```
Chunk 1 (scaffold)
  └── Chunk 2 (all module stubs)
        ├── Chunk 3 (iam + s3)
        ├── Chunk 4 (secrets)
        ├── Chunk 15 (agent-runtime)     ← NEW
        ├── Chunk 16 (agent-memory)      ← NEW
        ├── Chunk 17 (agent-gateway)     ← NEW
        ├── Chunk 18 (agent-scheduler)   ← NEW
        ├── Chunk 5 (bedrock-kb)         [needs: s3, iam]
        ├── Chunk 6 (ecs-service)        [needs: iam, secrets]
        └── Chunk 7 (observability)      [needs: ecs-service]
              └── Chunk 8 (composition root wires all)
                    └── Chunk 19 (fixes)
                          ├── Chunk 9 (datanp tfvars)
                          ├── Chunk 10 (dataprd tfvars)
                          ├── Chunk 11 (workflows)
                          ├── Chunk 12 (runner IAM)
                          ├── Chunk 13 (READMEs)
                          ├── Chunk 20 (versioning)
                          └── Chunk 14 (E2E + PR)
```

*Revised by kspec-verify on 2026-08-14. All verification gaps addressed.*
