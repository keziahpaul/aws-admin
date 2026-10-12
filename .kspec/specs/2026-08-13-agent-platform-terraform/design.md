# Technical Design: Agent Platform Terraform Modules

**Spec**: [DD-6600](https://pexa.atlassian.net/browse/DD-6600)
**Epic**: [DD-6592](https://pexa.atlassian.net/browse/DD-6592)
**Created**: 2026-08-13
**Status**: Draft

---

## 1. Architecture Overview

### 1.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS Account: datanp / dataprd                │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                   VPC (existing, data-vpc)                   │   │
│  │                                                              │   │
│  │  ┌─────────────────────┐   ┌──────────────────────────────┐ │   │
│  │  │  Private Subnets     │   │  ALB (internal)              │ │   │
│  │  │  (app tier)          │   │  /ping -> runtime:8080       │ │   │
│  │  │                      │   └──────────────┬───────────────┘ │   │
│  │  │  ┌───────────────┐  │                  │                 │   │
│  │  │  │ ECS Fargate   │  │◄─────────────────┘                 │   │
│  │  │  │ Service       │  │                                     │   │
│  │  │  │               │  │                                     │   │
│  │  │  │ ┌───────────┐ │  │                                     │   │
│  │  │  │ │ runtime   │ │  │   ┌──────────────────────────────┐ │   │
│  │  │  │ │ :8080     │ │──┼───►  Bedrock Knowledge Base      │ │   │
│  │  │  │ └───────────┘ │  │   │  (Titan Embed V2)            │ │   │
│  │  │  │ ┌───────────┐ │  │   │                              │ │   │
│  │  │  │ │ slack_bot │ │  │   │  ┌────────────────────────┐  │ │   │
│  │  │  │ │ (outbound)│ │  │   │  │ OpenSearch Serverless   │  │ │   │
│  │  │  │ └───────────┘ │  │   │  │ (vector store, shared) │  │ │   │
│  │  │  └───────────────┘  │   │  └────────────────────────┘  │ │   │
│  │  └─────────────────────┘   │                              │ │   │
│  │                            │  ┌────────────────────────┐  │ │   │
│  │                            │  │ S3 KB Bucket           │  │ │   │
│  │                            │  │ (source documents)     │  │ │   │
│  │                            │  └────────────────────────┘  │ │   │
│  │                            └──────────────────────────────┘ │   │
│  │                                                              │   │
│  │  ┌──────────────────────┐  ┌─────────────────────────────┐  │   │
│  │  │  Secrets Manager     │  │  CloudWatch                 │  │   │
│  │  │  - slack-bot-token   │  │  - Dashboard                │  │   │
│  │  │  - slack-signing     │  │  - Alarms                   │  │   │
│  │  │  - slack-app-token   │  │  - Log Groups               │  │   │
│  │  └──────────────────────┘  └─────────────────────────────┘  │   │
│  │                                                              │   │
│  │  ┌──────────────────────┐                                    │   │
│  │  │  IAM Roles           │                                    │   │
│  │  │  - task-exec-role    │                                    │   │
│  │  │  - task-role         │                                    │   │
│  │  │  - bedrock-kb-role   │                                    │   │
│  │  └──────────────────────┘                                    │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Module Dependency Graph

```
iam
 └─► ecs-service
 └─► bedrock-kb

s3-kb-bucket
 └─► bedrock-kb (data source)
 └─► iam (bucket ARN for task-role)

secrets
 └─► ecs-service (secret ARNs injected as env vars)
 └─► iam (task-exec-role gets secretsmanager:GetSecretValue)

bedrock-kb
 └─► observability (KB retrieval latency widget)

ecs-service
 └─► observability (ECS task unhealthy alarm, invocation metrics)

(All modules) ─► composition root (agent-platform/main.tf)
```

### 1.3 Deployment Flow

```
GitHub push (feature/* | develop | main | release/*)
  │
  ▼
deploy-pia-agent-platform.yml (caller)
  │
  ├─ Job: validate        → resolve account IDs + runner types
  ├─ Job: deploy-dev      → datanp, feature/* only
  ├─ Job: deploy-tst      → datanp, develop only
  ├─ Job: deploy-pst      → dataprd, main/release/* only
  └─ Job: deploy-prd      → dataprd, main/release/*, needs: deploy-pst
           │
           ▼
      reusable-agent-platform-deploy.yml
           │
           ├─ checkout
           ├─ OIDC assume role → GitHubRunnerAgentPlatformDeploymentRole
           ├─ terragrunt init
           ├─ terragrunt validate
           ├─ terragrunt plan -detailed-exitcode
           └─ terragrunt apply -auto-approve
```

---

## 2. Directory Layout

```
terraform/infrastructure/agent-platform/
  main.tf                    # Composition root - instantiates all modules per agent
  variables.tf               # agents list variable + shared vars
  outputs.tf                 # Per-agent output map
  versions.tf                # Provider + terraform version constraints
  terragrunt.hcl             # Inherits root terraform/terragrunt.hcl
  modules/
    ecs-service/
      main.tf
      variables.tf
      outputs.tf
    bedrock-kb/
      main.tf
      variables.tf
      outputs.tf
    secrets/
      main.tf
      variables.tf
      outputs.tf
    observability/
      main.tf
      variables.tf
      outputs.tf
    s3-kb-bucket/
      main.tf
      variables.tf
      outputs.tf
    iam/
      main.tf
      variables.tf
      outputs.tf
  environments/
    datanp/
      dev/
        terragrunt.hcl
        pia.auto.tfvars
      tst/
        terragrunt.hcl
        pia.auto.tfvars
    dataprd/
      pst/
        terragrunt.hcl
        pia.auto.tfvars
      prd/
        terragrunt.hcl
        pia.auto.tfvars

.github/workflows/
  reusable-agent-platform-deploy.yml
  deploy-pia-agent-platform.yml

.github/config/
  agent-platform-accounts.json
```

---

## 3. Composition Root

### 3.1 versions.tf

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  backend "s3" {}
}
```

### 3.2 variables.tf

```hcl
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Deployment environment (dev, tst, pst, prd)"
  type        = string
}

variable "project" {
  description = "Project name for tagging"
  type        = string
  default     = "agent-platform"
}

variable "cost_centre" {
  description = "Cost centre for billing tags"
  type        = string
  default     = "one-data"
}

# Networking - resolved from data sources using these names
variable "vpc_id" {
  description = "ID of the existing data VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "alb_listener_arn" {
  description = "ARN of the existing internal ALB listener to attach target groups to"
  type        = string
}

variable "use_fargate_spot" {
  description = "Use Fargate Spot capacity for cost reduction (non-prod only)"
  type        = bool
  default     = false
}

variable "agents" {
  description = "List of agent configurations to provision"
  type = list(object({
    name             = string
    runtime_image    = string
    slack_bot_image  = string
    runtime_cpu      = optional(number, 1024)
    runtime_memory   = optional(number, 2048)
    slack_bot_cpu    = optional(number, 512)
    slack_bot_memory = optional(number, 1024)
    kb_s3_prefix     = optional(string, "kb-documents/")
    kb_embedding_model = optional(string, "amazon.titan-embed-text-v2:0")
    # OpenSearch Serverless: use shared collection ARN to avoid $700/month per-agent cost
    opensearch_collection_arn      = optional(string, "")
    opensearch_collection_endpoint = optional(string, "")
    alarm_sns_emails               = list(string)
    tags                           = optional(map(string), {})
  }))
}

# Shared OpenSearch Serverless collection (shared across all agents to minimise cost)
variable "shared_opensearch_collection_name" {
  description = "Name of the shared OpenSearch Serverless collection for all agents"
  type        = string
  default     = "agent-platform-kb"
}

variable "create_opensearch_collection" {
  description = "Create the shared OpenSearch Serverless collection (set false if pre-existing)"
  type        = bool
  default     = true
}
```

### 3.3 main.tf

```hcl
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  common_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
    team        = "onedata"
  }

  agents_map = { for a in var.agents : a.name => a }
}

# ── Shared OpenSearch Serverless Collection ──────────────────────────────────
# One collection shared across all agents to avoid $700/month per-agent cost.
# Each agent gets its own index (namespace) within the collection.
resource "aws_opensearchserverless_collection" "shared" {
  count = var.create_opensearch_collection ? 1 : 0

  name = "${var.environment}-${var.shared_opensearch_collection_name}"
  type = "VECTORSEARCH"

  tags = merge(local.common_tags, {
    Name = "${var.environment}-${var.shared_opensearch_collection_name}"
  })

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
  ]
}

resource "aws_opensearchserverless_security_policy" "encryption" {
  count = var.create_opensearch_collection ? 1 : 0

  name = "${var.environment}-agent-platform-enc"
  type = "encryption"

  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${var.environment}-${var.shared_opensearch_collection_name}"]
    }]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  count = var.create_opensearch_collection ? 1 : 0

  name = "${var.environment}-agent-platform-net"
  type = "network"

  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.environment}-${var.shared_opensearch_collection_name}"]
      },
      {
        ResourceType = "dashboard"
        Resource     = ["collection/${var.environment}-${var.shared_opensearch_collection_name}"]
      }
    ]
    AllowFromPublic = false
    SourceVPCEs     = []
  }])
}

locals {
  opensearch_collection_arn      = var.create_opensearch_collection ? aws_opensearchserverless_collection.shared[0].arn : ""
  opensearch_collection_endpoint = var.create_opensearch_collection ? aws_opensearchserverless_collection.shared[0].collection_endpoint : ""
}

# ── Per-agent modules ────────────────────────────────────────────────────────
module "s3_kb_bucket" {
  source   = "./modules/s3-kb-bucket"
  for_each = local.agents_map

  agent_name  = each.key
  environment = var.environment
  project     = var.project
  tags        = merge(local.common_tags, each.value.tags, { agent_name = each.key })
}

module "iam" {
  source   = "./modules/iam"
  for_each = local.agents_map

  agent_name          = each.key
  environment         = var.environment
  aws_region          = var.aws_region
  account_id          = data.aws_caller_identity.current.account_id
  kb_bucket_arn       = module.s3_kb_bucket[each.key].bucket_arn
  secret_arns         = module.secrets[each.key].secret_arns
  opensearch_collection_arn = local.opensearch_collection_arn
  tags                = merge(local.common_tags, each.value.tags, { agent_name = each.key })
}

module "secrets" {
  source   = "./modules/secrets"
  for_each = local.agents_map

  agent_name  = each.key
  environment = var.environment
  tags        = merge(local.common_tags, each.value.tags, { agent_name = each.key })
}

module "bedrock_kb" {
  source   = "./modules/bedrock-kb"
  for_each = local.agents_map

  agent_name                     = each.key
  environment                    = var.environment
  kb_bucket_arn                  = module.s3_kb_bucket[each.key].bucket_arn
  kb_bucket_name                 = module.s3_kb_bucket[each.key].bucket_name
  kb_s3_prefix                   = each.value.kb_s3_prefix
  embedding_model_arn            = "arn:aws:bedrock:${var.aws_region}::foundation-model/${each.value.kb_embedding_model}"
  opensearch_collection_arn      = local.opensearch_collection_arn
  opensearch_collection_endpoint = local.opensearch_collection_endpoint
  bedrock_kb_role_arn            = module.iam[each.key].bedrock_kb_role_arn
  tags                           = merge(local.common_tags, each.value.tags, { agent_name = each.key })

  depends_on = [module.iam, module.s3_kb_bucket]
}

module "ecs_service" {
  source   = "./modules/ecs-service"
  for_each = local.agents_map

  agent_name          = each.key
  environment         = var.environment
  vpc_id              = var.vpc_id
  private_subnet_ids  = var.private_subnet_ids
  alb_listener_arn    = var.alb_listener_arn
  runtime_image       = each.value.runtime_image
  slack_bot_image     = each.value.slack_bot_image
  runtime_cpu         = each.value.runtime_cpu
  runtime_memory      = each.value.runtime_memory
  slack_bot_cpu       = each.value.slack_bot_cpu
  slack_bot_memory    = each.value.slack_bot_memory
  task_execution_role_arn = module.iam[each.key].task_execution_role_arn
  task_role_arn           = module.iam[each.key].task_role_arn
  use_fargate_spot    = var.use_fargate_spot
  secret_arns         = module.secrets[each.key].secret_arns
  kb_knowledge_base_id = module.bedrock_kb[each.key].knowledge_base_id
  tags                = merge(local.common_tags, each.value.tags, { agent_name = each.key })

  depends_on = [module.iam, module.secrets]
}

module "observability" {
  source   = "./modules/observability"
  for_each = local.agents_map

  agent_name           = each.key
  environment          = var.environment
  ecs_cluster_name     = module.ecs_service[each.key].cluster_name
  ecs_service_name     = module.ecs_service[each.key].service_name
  knowledge_base_id    = module.bedrock_kb[each.key].knowledge_base_id
  alarm_sns_emails     = each.value.alarm_sns_emails
  tags                 = merge(local.common_tags, each.value.tags, { agent_name = each.key })

  depends_on = [module.ecs_service, module.bedrock_kb]
}
```

### 3.4 outputs.tf

```hcl
output "agents" {
  description = "Per-agent output map"
  value = {
    for name, _ in local.agents_map : name => {
      ecs_cluster_name     = module.ecs_service[name].cluster_name
      ecs_service_name     = module.ecs_service[name].service_name
      knowledge_base_id    = module.bedrock_kb[name].knowledge_base_id
      kb_bucket_name       = module.s3_kb_bucket[name].bucket_name
      secret_arns          = module.secrets[name].secret_arns
      dashboard_name       = module.observability[name].dashboard_name
      alb_target_group_arn = module.ecs_service[name].alb_target_group_arn
    }
  }
}

output "opensearch_collection_arn" {
  description = "Shared OpenSearch Serverless collection ARN"
  value       = local.opensearch_collection_arn
}
```

---

## 4. Module Specifications

### 4.1 Module: iam

**Purpose**: Provision all IAM roles with least-privilege policies. Always created first; all other modules depend on its outputs.

#### variables.tf

```hcl
variable "agent_name"               { type = string }
variable "environment"              { type = string }
variable "aws_region"               { type = string }
variable "account_id"               { type = string }
variable "kb_bucket_arn"            { type = string }
variable "opensearch_collection_arn" { type = string }
variable "secret_arns"              { type = list(string) }
variable "tags"                     { type = map(string); default = {} }
```

#### main.tf (key resources)

```hcl
# 1. ECS Task Execution Role
resource "aws_iam_role" "task_execution" {
  name = "${var.environment}-${var.agent_name}-task-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_inline" {
  name = "AgentTaskExecutionPolicy"
  role = aws_iam_role.task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsAccess"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = var.secret_arns
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/ecs/${var.environment}-${var.agent_name}*"
      }
    ]
  })
}

# 2. ECS Task Role (runtime permissions)
resource "aws_iam_role" "task_role" {
  name = "${var.environment}-${var.agent_name}-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "task_role_inline" {
  name = "AgentTaskPolicy"
  role = aws_iam_role.task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/*"
      },
      {
        Sid    = "BedrockKBRetrieve"
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}:${var.account_id}:knowledge-base/*"
      },
      {
        Sid    = "S3KBRead"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [var.kb_bucket_arn, "${var.kb_bucket_arn}/*"]
      },
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "${upper(var.agent_name)}/Agent"
          }
        }
      }
    ]
  })
}

# 3. Bedrock KB Service Role
resource "aws_iam_role" "bedrock_kb" {
  name = "${var.environment}-${var.agent_name}-bedrock-kb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${var.account_id}:knowledge-base/*" }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "bedrock_kb_inline" {
  name = "BedrockKBPolicy"
  role = aws_iam_role.bedrock_kb.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DataSourceRead"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [var.kb_bucket_arn, "${var.kb_bucket_arn}/*"]
      },
      {
        Sid    = "EmbeddingModel"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
      },
      {
        Sid    = "OpenSearchAccess"
        Effect = "Allow"
        Action = ["aoss:APIAccessAll"]
        Resource = var.opensearch_collection_arn
      }
    ]
  })
}
```

#### outputs.tf

```hcl
output "task_execution_role_arn" { value = aws_iam_role.task_execution.arn }
output "task_execution_role_name" { value = aws_iam_role.task_execution.name }
output "task_role_arn"            { value = aws_iam_role.task_role.arn }
output "task_role_name"           { value = aws_iam_role.task_role.name }
output "bedrock_kb_role_arn"      { value = aws_iam_role.bedrock_kb.arn }
output "bedrock_kb_role_name"     { value = aws_iam_role.bedrock_kb.name }
```

---

### 4.2 Module: s3-kb-bucket

**Purpose**: Provision the S3 bucket that stores KB source documents. SSE-S3 (not KMS) to allow Bedrock service access without KMS policy complexity.

#### variables.tf

```hcl
variable "agent_name"  { type = string }
variable "environment" { type = string }
variable "project"     { type = string; default = "agent-platform" }
variable "tags"        { type = map(string); default = {} }
```

#### main.tf

```hcl
data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.environment}-${var.agent_name}-kb-documents-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "kb" {
  bucket = local.bucket_name
  tags   = merge(var.tags, { Name = local.bucket_name })
}

resource "aws_s3_bucket_versioning" "kb" {
  bucket = aws_s3_bucket.kb.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kb" {
  bucket = aws_s3_bucket.kb.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "kb" {
  bucket                  = aws_s3_bucket.kb.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "kb" {
  bucket = aws_s3_bucket.kb.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }
}

# Allow Bedrock service to read objects
data "aws_iam_policy_document" "bedrock_access" {
  statement {
    sid    = "BedrockRead"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.kb.arn, "${aws_s3_bucket.kb.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "kb" {
  bucket = aws_s3_bucket.kb.id
  policy = data.aws_iam_policy_document.bedrock_access.json
}
```

#### outputs.tf

```hcl
output "bucket_name" { value = aws_s3_bucket.kb.bucket }
output "bucket_arn"  { value = aws_s3_bucket.kb.arn }
output "bucket_id"   { value = aws_s3_bucket.kb.id }
```

---

### 4.3 Module: secrets

**Purpose**: Provision three Secrets Manager secrets per agent. Placeholder values only - real tokens injected post-deploy via CLI or console.

#### variables.tf

```hcl
variable "agent_name"  { type = string }
variable "environment" { type = string }
variable "tags"        { type = map(string); default = {} }
```

#### main.tf

```hcl
locals {
  secret_prefix = "${var.environment}/${var.agent_name}"
  secrets = {
    slack-bot-token    = "Slack Bot OAuth Token (xoxb-...) - inject post-deploy"
    slack-signing-secret = "Slack Signing Secret - inject post-deploy"
    slack-app-token    = "Slack App-Level Token (xapp-...) for Socket Mode - inject post-deploy"
  }
}

resource "aws_secretsmanager_secret" "agent" {
  for_each = local.secrets

  name        = "${local.secret_prefix}/${each.key}"
  description = each.value

  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name       = "${local.secret_prefix}/${each.key}"
    SecretType = each.key
  })
}

# Placeholder initial version so ECS can reference the ARN at deploy time.
# Real values must be set manually before starting the ECS service.
resource "aws_secretsmanager_secret_version" "agent" {
  for_each = local.secrets

  secret_id     = aws_secretsmanager_secret.agent[each.key].id
  secret_string = jsonencode({ value = "PLACEHOLDER-replace-before-starting-service" })

  lifecycle {
    # Prevent Terraform from overwriting manually injected secret values
    ignore_changes = [secret_string]
  }
}
```

#### outputs.tf

```hcl
output "secret_arns" {
  description = "Map of secret name to ARN"
  value = {
    for k, s in aws_secretsmanager_secret.agent : k => s.arn
  }
}

output "secret_names" {
  description = "Map of secret name to full Secrets Manager path"
  value = {
    for k, s in aws_secretsmanager_secret.agent : k => s.name
  }
}

# List of ARNs for use in IAM policy resources
output "secret_arns_list" {
  value = [for s in aws_secretsmanager_secret.agent : s.arn]
}
```

---

### 4.4 Module: bedrock-kb

**Purpose**: Provision a Bedrock Knowledge Base backed by OpenSearch Serverless. Uses the shared collection with an agent-specific index to amortise the ~$700/month base cost.

#### variables.tf

```hcl
variable "agent_name"                     { type = string }
variable "environment"                    { type = string }
variable "kb_bucket_arn"                  { type = string }
variable "kb_bucket_name"                 { type = string }
variable "kb_s3_prefix"                   { type = string; default = "kb-documents/" }
variable "embedding_model_arn"            { type = string }
variable "opensearch_collection_arn"      { type = string }
variable "opensearch_collection_endpoint" { type = string }
variable "bedrock_kb_role_arn"            { type = string }
variable "tags"                           { type = map(string); default = {} }
```

#### main.tf

```hcl
locals {
  kb_name    = "${var.environment}-${var.agent_name}-kb"
  index_name = "${var.environment}-${var.agent_name}-index"
}

# OpenSearch data access policy - grant Bedrock KB role access to this agent's index
resource "aws_opensearchserverless_access_policy" "bedrock_kb" {
  name = "${var.environment}-${var.agent_name}-kb-access"
  type = "data"

  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "index"
        Resource     = ["index/${var.environment}-agent-platform-kb/${local.index_name}"]
        Permission   = [
          "aoss:CreateIndex",
          "aoss:DeleteIndex",
          "aoss:UpdateIndex",
          "aoss:DescribeIndex",
          "aoss:ReadDocument",
          "aoss:WriteDocument"
        ]
      },
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.environment}-agent-platform-kb"]
        Permission   = ["aoss:DescribeCollectionItems"]
      }
    ]
    Principal = [var.bedrock_kb_role_arn]
  }])
}

resource "aws_bedrockagent_knowledge_base" "this" {
  name        = local.kb_name
  description = "Knowledge base for ${var.agent_name} agent in ${var.environment}"
  role_arn    = var.bedrock_kb_role_arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = var.embedding_model_arn
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = var.opensearch_collection_arn
      vector_index_name = local.index_name
      field_mapping {
        vector_field   = "embedding"
        text_field     = "text"
        metadata_field = "metadata"
      }
    }
  }

  tags = var.tags

  depends_on = [aws_opensearchserverless_access_policy.bedrock_kb]
}

resource "aws_bedrockagent_data_source" "s3" {
  name             = "${local.kb_name}-s3-source"
  knowledge_base_id = aws_bedrockagent_knowledge_base.this.id
  data_deletion_policy = "RETAIN"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = var.kb_bucket_arn
      inclusion_prefixes = [var.kb_s3_prefix]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 512
        overlap_percentage = 20
      }
    }
  }
}
```

#### outputs.tf

```hcl
output "knowledge_base_id"      { value = aws_bedrockagent_knowledge_base.this.id }
output "knowledge_base_arn"     { value = aws_bedrockagent_knowledge_base.this.arn }
output "data_source_id"         { value = aws_bedrockagent_data_source.s3.data_source_id }
output "index_name"             { value = local.index_name }
```

---

### 4.5 Module: ecs-service

**Purpose**: ECS Fargate service with two containers (runtime + slack_bot), an internal ALB target group, auto-scaling, and CloudWatch log groups.

#### variables.tf

```hcl
variable "agent_name"               { type = string }
variable "environment"              { type = string }
variable "vpc_id"                   { type = string }
variable "private_subnet_ids"       { type = list(string) }
variable "alb_listener_arn"         { type = string }
variable "runtime_image"            { type = string }
variable "slack_bot_image"          { type = string }
variable "runtime_cpu"              { type = number; default = 1024 }
variable "runtime_memory"           { type = number; default = 2048 }
variable "slack_bot_cpu"            { type = number; default = 512 }
variable "slack_bot_memory"         { type = number; default = 1024 }
variable "runtime_port"             { type = number; default = 8080 }
variable "health_check_path"        { type = string; default = "/ping" }
variable "desired_count"            { type = number; default = 1 }
variable "autoscaling_min"          { type = number; default = 1 }
variable "autoscaling_max"          { type = number; default = 3 }
variable "task_execution_role_arn"  { type = string }
variable "task_role_arn"            { type = string }
variable "use_fargate_spot"         { type = bool; default = false }
variable "secret_arns"              { type = map(string) }
variable "kb_knowledge_base_id"     { type = string }
variable "log_retention_days"       { type = number; default = 30 }
variable "tags"                     { type = map(string); default = {} }
```

#### main.tf

```hcl
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  cluster_name = "${var.environment}-${var.agent_name}-cluster"
  service_name = "${var.environment}-${var.agent_name}-service"
  # Task definition runs TWO containers: runtime + slack_bot
  # Total CPU/memory = sum of both containers
  task_cpu    = var.runtime_cpu + var.slack_bot_cpu
  task_memory = var.runtime_memory + var.slack_bot_memory
}

# ── ECS Cluster ──────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = var.use_fargate_spot ? ["FARGATE", "FARGATE_SPOT"] : ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"
    weight            = 1
    base              = 1
  }
}

# ── CloudWatch Log Groups ─────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "runtime" {
  name              = "/ecs/${var.environment}-${var.agent_name}/runtime"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "slack_bot" {
  name              = "/ecs/${var.environment}-${var.agent_name}/slack-bot"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ── Security Group ────────────────────────────────────────────────────────────
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.environment}-${var.agent_name}-ecs-tasks-sg"
  description = "Security group for ${var.agent_name} ECS tasks"
  vpc_id      = var.vpc_id

  # Inbound from ALB only on runtime port
  ingress {
    description     = "HTTP from ALB"
    from_port       = var.runtime_port
    to_port         = var.runtime_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Outbound to AWS services (Bedrock, Secrets Manager, S3, OpenSearch)
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.environment}-${var.agent_name}-ecs-tasks-sg" })
}

resource "aws_security_group" "alb" {
  name        = "${var.environment}-${var.agent_name}-alb-sg"
  description = "Security group for ${var.agent_name} internal ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS internal"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.environment}-${var.agent_name}-alb-sg" })
}

# ── ALB Target Group ──────────────────────────────────────────────────────────
resource "aws_lb_target_group" "runtime" {
  name        = "${var.environment}-${var.agent_name}-tg"
  port        = var.runtime_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = var.tags
}

resource "aws_lb_listener_rule" "runtime" {
  listener_arn = var.alb_listener_arn
  priority     = null # auto-assigned

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.runtime.arn
  }

  condition {
    host_header {
      values = ["${var.agent_name}.${var.environment}.internal"]
    }
  }
}

# ── Task Definition ───────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.environment}-${var.agent_name}"
  cpu                      = local.task_cpu
  memory                   = local.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "runtime"
      image     = var.runtime_image
      essential = true
      cpu       = var.runtime_cpu
      memory    = var.runtime_memory
      portMappings = [{
        containerPort = var.runtime_port
        protocol      = "tcp"
      }]
      environment = [
        { name = "ENVIRONMENT",       value = var.environment },
        { name = "KB_KNOWLEDGE_BASE_ID", value = var.kb_knowledge_base_id },
        { name = "AWS_REGION",        value = data.aws_region.current.name }
      ]
      secrets = [
        { name = "SLACK_BOT_TOKEN",    valueFrom = var.secret_arns["slack-bot-token"] },
        { name = "SLACK_SIGNING_SECRET", valueFrom = var.secret_arns["slack-signing-secret"] }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.runtime.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "runtime"
        }
      }
    },
    {
      name      = "slack-bot"
      image     = var.slack_bot_image
      essential = true
      cpu       = var.slack_bot_cpu
      memory    = var.slack_bot_memory
      # No port mapping - Socket Mode uses outbound WebSocket only
      environment = [
        { name = "ENVIRONMENT", value = var.environment },
        { name = "AWS_REGION",  value = data.aws_region.current.name }
      ]
      secrets = [
        { name = "SLACK_APP_TOKEN", valueFrom = var.secret_arns["slack-app-token"] },
        { name = "SLACK_BOT_TOKEN", valueFrom = var.secret_arns["slack-bot-token"] }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.slack_bot.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "slack-bot"
        }
      }
    }
  ])

  tags = var.tags
}

# ── ECS Service ───────────────────────────────────────────────────────────────
resource "aws_ecs_service" "this" {
  name            = local.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  capacity_provider_strategy {
    capacity_provider = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"
    weight            = 1
    base              = 1
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.runtime.arn
    container_name   = "runtime"
    container_port   = var.runtime_port
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"

  tags = var.tags

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  depends_on = [aws_lb_listener_rule.runtime]
}

# ── Auto Scaling ──────────────────────────────────────────────────────────────
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.autoscaling_max
  min_capacity       = var.autoscaling_min
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
```

#### outputs.tf

```hcl
output "cluster_name"          { value = aws_ecs_cluster.this.name }
output "cluster_arn"           { value = aws_ecs_cluster.this.arn }
output "service_name"          { value = aws_ecs_service.this.name }
output "service_arn"           { value = aws_ecs_service.this.id }
output "task_definition_arn"   { value = aws_ecs_task_definition.this.arn }
output "alb_target_group_arn"  { value = aws_lb_target_group.runtime.arn }
output "ecs_tasks_sg_id"       { value = aws_security_group.ecs_tasks.id }
output "runtime_log_group"     { value = aws_cloudwatch_log_group.runtime.name }
output "slack_bot_log_group"   { value = aws_cloudwatch_log_group.slack_bot.name }
```

---

### 4.6 Module: observability

**Purpose**: CloudWatch dashboard, alarms, and SNS topic per agent.

#### variables.tf

```hcl
variable "agent_name"        { type = string }
variable "environment"       { type = string }
variable "ecs_cluster_name"  { type = string }
variable "ecs_service_name"  { type = string }
variable "knowledge_base_id" { type = string }
variable "alarm_sns_emails"  { type = list(string) }
variable "tags"              { type = map(string); default = {} }
```

#### main.tf

```hcl
data "aws_region" "current" {}

locals {
  metric_namespace = "${upper(var.agent_name)}/Agent"
  alarm_prefix     = "${var.environment}-${var.agent_name}"
}

resource "aws_sns_topic" "alarms" {
  name = "${local.alarm_prefix}-alarms"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = length(var.alarm_sns_emails)
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_sns_emails[count.index]
}

# ── CloudWatch Alarms ─────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "error_rate" {
  alarm_name          = "${local.alarm_prefix}-error-rate-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorCount"
  namespace           = local.metric_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Error rate > 5% for 5 minutes"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "p99_latency" {
  alarm_name          = "${local.alarm_prefix}-p99-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ResponseLatency"
  namespace           = local.metric_namespace
  period              = 300
  extended_statistic  = "p99"
  threshold           = 30000
  alarm_description   = "P99 latency > 30s"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_unhealthy" {
  alarm_name          = "${local.alarm_prefix}-ecs-unhealthy-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
  alarm_description  = "ECS running task count below 1"
  alarm_actions      = [aws_sns_topic.alarms.arn]
  ok_actions         = [aws_sns_topic.alarms.arn]
  treat_missing_data = "breaching"
  tags               = var.tags
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "agent" {
  dashboard_name = "${local.alarm_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x = 0; y = 0; width = 12; height = 6
        properties = {
          title  = "Invocation Count"
          region = data.aws_region.current.name
          metrics = [
            [local.metric_namespace, "InvocationCount", { stat = "Sum", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x = 12; y = 0; width = 12; height = 6
        properties = {
          title  = "Response Latency (P50/P95/P99)"
          region = data.aws_region.current.name
          metrics = [
            [local.metric_namespace, "ResponseLatency", { stat = "p50", period = 300, label = "P50" }],
            [local.metric_namespace, "ResponseLatency", { stat = "p95", period = 300, label = "P95" }],
            [local.metric_namespace, "ResponseLatency", { stat = "p99", period = 300, label = "P99" }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x = 0; y = 6; width = 12; height = 6
        properties = {
          title  = "Error Rate"
          region = data.aws_region.current.name
          metrics = [
            [local.metric_namespace, "ErrorCount", { stat = "Sum", period = 300 }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x = 12; y = 6; width = 12; height = 6
        properties = {
          title  = "KB Retrieval Latency"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Bedrock", "KnowledgeBaseRetrieveAndGenerateLatency",
              "KnowledgeBaseId", var.knowledge_base_id,
              { stat = "p99", period = 300, label = "Retrieve P99" }]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "metric"
        x = 0; y = 12; width = 12; height = 6
        properties = {
          title  = "ECS Running Task Count"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ECS", "RunningTaskCount",
              "ClusterName", var.ecs_cluster_name,
              "ServiceName", var.ecs_service_name,
              { stat = "Average", period = 60 }]
          ]
          view = "timeSeries"
        }
      }
    ]
  })
}
```

#### outputs.tf

```hcl
output "sns_topic_arn"   { value = aws_sns_topic.alarms.arn }
output "dashboard_name"  { value = aws_cloudwatch_dashboard.agent.dashboard_name }
output "alarm_arns" {
  value = {
    error_rate    = aws_cloudwatch_metric_alarm.error_rate.arn
    p99_latency   = aws_cloudwatch_metric_alarm.p99_latency.arn
    ecs_unhealthy = aws_cloudwatch_metric_alarm.ecs_unhealthy.arn
  }
}
```

---

## 5. Terragrunt Configuration

### 5.1 Module-level terragrunt.hcl

`terraform/infrastructure/agent-platform/terragrunt.hcl`

```hcl
# Inherit root provider/backend generation from terraform/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}
```

### 5.2 Environment-level: datanp/dev

`terraform/infrastructure/agent-platform/environments/datanp/dev/terragrunt.hcl`

```hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../.."
}

remote_state {
  backend = "s3"
  config = {
    bucket               = "remote-tfstate-ap-southeast-2-042775015153"
    key                  = "infrastructure/agent-platform/datanp/dev/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "onedata"
    skip_bucket_versioning              = true
    skip_bucket_ssencryption            = true
    skip_bucket_public_access_blocking  = true
    skip_bucket_root_access             = true
  }
}

inputs = {
  environment  = "dev"
  project      = "agent-platform"
  cost_centre  = "one-data"
  aws_region   = "ap-southeast-2"
}
```

### 5.3 Environment-level: datanp/tst

`terraform/infrastructure/agent-platform/environments/datanp/tst/terragrunt.hcl`

```hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../.."
}

remote_state {
  backend = "s3"
  config = {
    bucket               = "remote-tfstate-ap-southeast-2-042775015153"
    key                  = "infrastructure/agent-platform/datanp/tst/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "onedata"
    skip_bucket_versioning              = true
    skip_bucket_ssencryption            = true
    skip_bucket_public_access_blocking  = true
    skip_bucket_root_access             = true
  }
}

inputs = {
  environment  = "tst"
  project      = "agent-platform"
  cost_centre  = "one-data"
  aws_region   = "ap-southeast-2"
}
```

---

## 6. Environment-Specific tfvars (PIA, datanp)

`terraform/infrastructure/agent-platform/environments/datanp/dev/pia.auto.tfvars`

```hcl
# ── Networking ────────────────────────────────────────────────────────────────
# These values must match the existing data-vpc in the datanp account.
# Look up with: aws ec2 describe-vpcs --filters "Name=tag:Name,Values=data-vpc"
vpc_id             = "vpc-0abc1234def567890"
private_subnet_ids = ["subnet-0aaa1111", "subnet-0bbb2222"]
alb_listener_arn   = "arn:aws:elasticloadbalancing:ap-southeast-2:042775015153:listener/app/data-internal-alb/..."

# Use Fargate Spot for non-prod cost reduction
use_fargate_spot = true

# One shared OpenSearch Serverless collection for all agents
create_opensearch_collection      = true
shared_opensearch_collection_name = "agent-platform-kb"

# ── Agents ────────────────────────────────────────────────────────────────────
agents = [
  {
    name             = "pia"
    runtime_image    = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/pia-agent-runtime:latest"
    slack_bot_image  = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/pia-agent-slack-bot:latest"
    runtime_cpu      = 1024
    runtime_memory   = 2048
    slack_bot_cpu    = 512
    slack_bot_memory = 1024
    kb_s3_prefix     = "kb-documents/"
    kb_embedding_model = "amazon.titan-embed-text-v2:0"
    alarm_sns_emails = ["platform-alerts-dev@pexa.com.au"]
    tags = {
      component = "pia-agent"
    }
  }
]
```

`terraform/infrastructure/agent-platform/environments/datanp/tst/pia.auto.tfvars` — same structure, update `alarm_sns_emails` and image tags to `:tst` or `:develop` as appropriate.

`terraform/infrastructure/agent-platform/environments/dataprd/prd/pia.auto.tfvars`

```hcl
vpc_id             = "vpc-0prod1234def567890"
private_subnet_ids = ["subnet-0prod1111", "subnet-0prod2222"]
alb_listener_arn   = "arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:listener/..."

# On-demand for production (no Spot)
use_fargate_spot = false

create_opensearch_collection      = true
shared_opensearch_collection_name = "agent-platform-kb"

agents = [
  {
    name             = "pia"
    runtime_image    = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/pia-agent-runtime:v1.0.0"
    slack_bot_image  = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/pia-agent-slack-bot:v1.0.0"
    runtime_cpu      = 2048
    runtime_memory   = 4096
    slack_bot_cpu    = 512
    slack_bot_memory = 1024
    kb_s3_prefix     = "kb-documents/"
    kb_embedding_model = "amazon.titan-embed-text-v2:0"
    alarm_sns_emails = ["platform-alerts-prd@pexa.com.au", "oncall@pexa.com.au"]
    tags = {
      component = "pia-agent"
    }
  }
]
```

---

## 7. GitHub Actions Workflows

### 7.1 Account Configuration

`.github/config/agent-platform-accounts.json`

```json
{
  "accounts": {
    "datanp": {
      "account_id": "042775015153",
      "environments": ["dev", "tst"],
      "runner_type": "non-prod",
      "description": "Data Non-Production Account"
    },
    "dataprd": {
      "account_id": "DATAPRD_ACCOUNT_ID",
      "environments": ["pst", "prd"],
      "runner_type": "prod",
      "description": "Data Production Account"
    }
  },
  "terragrunt": {
    "base_path": "terraform/infrastructure/agent-platform",
    "root_config": "terraform/terragrunt.hcl",
    "folder_pattern": "environments/{account}/{environment}/"
  },
  "metadata": {
    "version": "1.0",
    "last_updated": "2026-08-13",
    "purpose": "Agent Platform Terragrunt deployment configuration",
    "deployment_tool": "terragrunt",
    "iam_role": "GitHubRunnerAgentPlatformDeploymentRole"
  }
}
```

### 7.2 Reusable Workflow

`.github/workflows/reusable-agent-platform-deploy.yml`

```yaml
name: Deploy Agent Platform [Reusable - Terragrunt]

on:
  workflow_call:
    inputs:
      environment:
        description: 'Environment to deploy to'
        type: string
        required: true
      runner-type:
        description: 'Type of runner: "prod" or "non-prod"'
        type: string
        required: true
      aws-account:
        description: 'AWS account ID'
        required: true
        type: string
      terragrunt-path:
        description: 'Path to Terragrunt configuration directory'
        type: string
        required: true
      no-execute-changeset:
        description: 'Dry run - plan only, no apply'
        type: boolean
        required: false
        default: false
    outputs:
      plan-exitcode:
        description: 'Terragrunt plan exit code (0=no-change, 2=changes)'
        value: ${{ jobs.deploy.outputs.plan-exitcode }}
      deployment-status:
        description: 'Overall deployment status'
        value: ${{ jobs.deploy.outputs.status }}

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    name: Deploy Agent Platform Infrastructure
    runs-on: ['${{ inputs.runner-type }}', 'deploy']
    environment: ${{ inputs.environment }}
    container:
      image: '004761221582.dkr.ecr.ap-southeast-2.amazonaws.com/apim-kong-provisioning:latest'
      volumes:
        - /home/github/.ssh/runner_ssh:/root/.ssh/id_rsa
        - /home/github/.ssh/known_hosts:/root/.ssh/known_hosts
    outputs:
      plan-exitcode: ${{ steps.plan.outputs.exitcode }}
      status: ${{ steps.status.outputs.result }}

    steps:
      - name: Deployment Information
        run: |
          echo "## Agent Platform Infrastructure Deployment" >> $GITHUB_STEP_SUMMARY
          echo "| Parameter | Value |" >> $GITHUB_STEP_SUMMARY
          echo "|-----------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| **Environment** | ${{ inputs.environment }} |" >> $GITHUB_STEP_SUMMARY
          echo "| **AWS Account** | ${{ inputs.aws-account }} |" >> $GITHUB_STEP_SUMMARY
          echo "| **Terragrunt Path** | ${{ inputs.terragrunt-path }} |" >> $GITHUB_STEP_SUMMARY
          echo "| **Dry Run** | ${{ inputs.no-execute-changeset }} |" >> $GITHUB_STEP_SUMMARY

      - name: Checkout Source Code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ inputs.aws-account }}:role/GitHubRunnerAgentPlatformDeploymentRole
          role-duration-seconds: 1800
          role-skip-session-tagging: true
          aws-region: ap-southeast-2

      - name: Terragrunt Init
        id: init
        working-directory: ${{ inputs.terragrunt-path }}
        run: terragrunt init

      - name: Terragrunt Validate
        id: validate
        working-directory: ${{ inputs.terragrunt-path }}
        run: terragrunt validate

      - name: Terragrunt Plan
        id: plan
        working-directory: ${{ inputs.terragrunt-path }}
        run: |
          set +e
          terragrunt plan -detailed-exitcode
          PLAN_EXIT_CODE=$?
          echo "exitcode=$PLAN_EXIT_CODE" >> $GITHUB_OUTPUT
          case $PLAN_EXIT_CODE in
            0) echo "plan-status=no-changes" >> $GITHUB_OUTPUT ;;
            1) echo "plan-status=failed" >> $GITHUB_OUTPUT; exit 1 ;;
            2) echo "plan-status=changes-detected" >> $GITHUB_OUTPUT ;;
          esac

      - name: Terragrunt Apply
        id: apply
        if: |
          !inputs.no-execute-changeset &&
          steps.plan.outputs.exitcode == '2'
        working-directory: ${{ inputs.terragrunt-path }}
        run: terragrunt apply -auto-approve

      - name: Show Outputs
        if: steps.apply.outcome == 'success' || steps.plan.outputs.exitcode == '0'
        working-directory: ${{ inputs.terragrunt-path }}
        run: |
          echo "## Terragrunt Outputs" >> $GITHUB_STEP_SUMMARY
          echo '```' >> $GITHUB_STEP_SUMMARY
          terragrunt output 2>/dev/null >> $GITHUB_STEP_SUMMARY || echo "No outputs available" >> $GITHUB_STEP_SUMMARY
          echo '```' >> $GITHUB_STEP_SUMMARY

      - name: Set Job Status
        id: status
        if: always()
        run: |
          if [[ "${{ steps.apply.outcome }}" == "success" ]] || [[ "${{ steps.plan.outputs.exitcode }}" == "0" ]]; then
            echo "result=success" >> $GITHUB_OUTPUT
          elif [[ "${{ inputs.no-execute-changeset }}" == "true" ]] && [[ "${{ steps.plan.outcome }}" == "success" ]]; then
            echo "result=dry-run-success" >> $GITHUB_OUTPUT
          else
            echo "result=failed" >> $GITHUB_OUTPUT
          fi

      - name: Cleanup
        if: always()
        run: |
          find ${{ inputs.terragrunt-path }} -name ".terragrunt-cache" -type d -exec rm -rf {} + 2>/dev/null || true
```

### 7.3 PIA Caller Workflow

`.github/workflows/deploy-pia-agent-platform.yml`

```yaml
name: Deploy PIA Agent Platform

on:
  push:
    branches:
      - 'feature/*'
      - develop
      - main
      - 'release/*'
  workflow_dispatch:
    inputs:
      no-execute-changeset:
        description: 'Dry run - plan only'
        type: boolean
        required: false
        default: false

permissions:
  id-token: write
  contents: read

jobs:
  validate:
    name: Validate Configuration
    runs-on: ['non-prod', 'deploy']
    outputs:
      datanp-account-id:  ${{ steps.config.outputs.datanp-account-id }}
      dataprd-account-id: ${{ steps.config.outputs.dataprd-account-id }}
    steps:
      - name: Checkout Source Code
        uses: actions/checkout@v4

      - name: Load Account Configuration
        id: config
        run: |
          CONFIG=".github/config/agent-platform-accounts.json"
          DATANP_ID=$(jq -r '.accounts.datanp.account_id' "$CONFIG")
          DATAPRD_ID=$(jq -r '.accounts.dataprd.account_id' "$CONFIG")
          echo "datanp-account-id=$DATANP_ID" >> $GITHUB_OUTPUT
          echo "dataprd-account-id=$DATAPRD_ID" >> $GITHUB_OUTPUT

  # ── DEV: feature/* branches only ──────────────────────────────────────────
  deploy-dev:
    name: Deploy DEV (datanp)
    needs: validate
    if: github.ref_type == 'branch' && startsWith(github.ref_name, 'feature/')
    uses: ./.github/workflows/reusable-agent-platform-deploy.yml
    with:
      environment:      dev
      runner-type:      non-prod
      aws-account:      ${{ needs.validate.outputs.datanp-account-id }}
      terragrunt-path:  terraform/infrastructure/agent-platform/environments/datanp/dev
      no-execute-changeset: ${{ inputs.no-execute-changeset || false }}

  # ── TST: develop branch only ───────────────────────────────────────────────
  deploy-tst:
    name: Deploy TST (datanp)
    needs: validate
    if: github.ref_name == 'develop'
    uses: ./.github/workflows/reusable-agent-platform-deploy.yml
    with:
      environment:      tst
      runner-type:      non-prod
      aws-account:      ${{ needs.validate.outputs.datanp-account-id }}
      terragrunt-path:  terraform/infrastructure/agent-platform/environments/datanp/tst
      no-execute-changeset: ${{ inputs.no-execute-changeset || false }}

  # ── PST: main or release/* branches ───────────────────────────────────────
  deploy-pst:
    name: Deploy PST (dataprd)
    needs: validate
    if: |
      github.ref_name == 'main' ||
      startsWith(github.ref_name, 'release/')
    uses: ./.github/workflows/reusable-agent-platform-deploy.yml
    with:
      environment:      pst
      runner-type:      prod
      aws-account:      ${{ needs.validate.outputs.dataprd-account-id }}
      terragrunt-path:  terraform/infrastructure/agent-platform/environments/dataprd/pst
      no-execute-changeset: ${{ inputs.no-execute-changeset || false }}

  # ── PRD: main or release/*, sequential gate after PST ─────────────────────
  deploy-prd:
    name: Deploy PRD (dataprd)
    needs: [validate, deploy-pst]
    if: |
      github.ref_name == 'main' ||
      startsWith(github.ref_name, 'release/')
    uses: ./.github/workflows/reusable-agent-platform-deploy.yml
    with:
      environment:      prd
      runner-type:      prod
      aws-account:      ${{ needs.validate.outputs.dataprd-account-id }}
      terragrunt-path:  terraform/infrastructure/agent-platform/environments/dataprd/prd
      no-execute-changeset: ${{ inputs.no-execute-changeset || false }}
```

---

## 8. Network Architecture

### 8.1 VPC and Subnet Strategy

All resources deploy into the existing data VPC in `datanp` / `dataprd`. No new VPC is created.

```
data-vpc (10.x.0.0/16 - existing)
  ├── Private App Subnets (multi-AZ)
  │     ap-southeast-2a: 10.x.10.0/24
  │     ap-southeast-2b: 10.x.11.0/24
  │   Used by: ECS tasks
  │
  ├── Internal ALB Subnets (multi-AZ, reuses app tier or dedicated)
  │   Used by: Application Load Balancer
  │
  └── VPC Endpoints (existing or to be added)
        com.amazonaws.ap-southeast-2.ecr.api
        com.amazonaws.ap-southeast-2.ecr.dkr
        com.amazonaws.ap-southeast-2.s3 (gateway)
        com.amazonaws.ap-southeast-2.secretsmanager
        com.amazonaws.ap-southeast-2.logs
        com.amazonaws.ap-southeast-2.bedrock-runtime
        com.amazonaws.ap-southeast-2.bedrock-agent-runtime
```

### 8.2 Security Group Rules

| SG | Direction | Port | Source/Dest | Purpose |
|----|-----------|------|-------------|---------|
| alb-sg | Inbound | 443 | 10.0.0.0/8 | HTTPS from internal network |
| alb-sg | Outbound | All | 0.0.0.0/0 | Forward to ECS tasks |
| ecs-tasks-sg | Inbound | 8080 | alb-sg | Health checks + traffic |
| ecs-tasks-sg | Outbound | 443 | 0.0.0.0/0 | AWS APIs via VPC endpoints |

### 8.3 No Public Endpoints

- ALB is `internal` scheme (no internet-facing)
- ECS tasks: `assign_public_ip = false`
- S3 bucket: all public access blocked
- Slack bot uses outbound WebSocket (Socket Mode) - no inbound required
- OpenSearch Serverless network policy: `AllowFromPublic = false`

---

## 9. IAM Policy Summary

### 9.1 ECS Task Execution Role

Allows the ECS control plane to pull images and inject secrets into containers.

| Action | Resource | Purpose |
|--------|----------|---------|
| `ecr:GetAuthorizationToken` | `*` | ECR login |
| `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer` | ECR repo ARNs | Pull container images |
| `logs:CreateLogStream`, `logs:PutLogEvents` | `/ecs/{env}-{agent}*` | Write container logs |
| `secretsmanager:GetSecretValue` | Secret ARNs (scoped) | Inject Slack tokens at container start |

Via managed policy `AmazonECSTaskExecutionRolePolicy` plus inline for scoped secrets access.

### 9.2 ECS Task Role

Allows the running container to call AWS services.

| Action | Resource | Purpose |
|--------|----------|---------|
| `bedrock:InvokeModel`, `bedrock:InvokeModelWithResponseStream` | `arn:aws:bedrock:*::foundation-model/*` | LLM inference |
| `bedrock:Retrieve`, `bedrock:RetrieveAndGenerate` | `arn:aws:bedrock:{region}:{account}:knowledge-base/*` | KB retrieval |
| `s3:GetObject`, `s3:ListBucket` | KB bucket ARN only | Read KB source docs if needed |
| `cloudwatch:PutMetricData` | `*` with namespace condition | Custom metrics |

### 9.3 Bedrock KB Service Role

| Action | Resource | Purpose |
|--------|----------|---------|
| `s3:GetObject`, `s3:ListBucket` | KB bucket ARN | Read source documents |
| `bedrock:InvokeModel` | Titan Embed V2 model ARN | Generate embeddings |
| `aoss:APIAccessAll` | OpenSearch collection ARN | Write vectors to index |

Trust policy includes source account and source ARN conditions to prevent confused deputy.

### 9.4 GitHub Runner Role (pre-existing, needs update)

The existing `GitHubRunnerAgentPlatformDeploymentRole` (to be created) needs:

```json
{
  "Effect": "Allow",
  "Action": [
    "ecs:*", "ecr:*", "iam:*",
    "bedrock:*", "aoss:*",
    "s3:*", "secretsmanager:*",
    "cloudwatch:*", "sns:*",
    "logs:*", "application-autoscaling:*",
    "elasticloadbalancing:*",
    "ec2:DescribeVpcs", "ec2:DescribeSubnets",
    "ec2:DescribeSecurityGroups",
    "ec2:CreateSecurityGroup", "ec2:AuthorizeSecurityGroupIngress",
    "ec2:AuthorizeSecurityGroupEgress", "ec2:DeleteSecurityGroup",
    "ec2:RevokeSecurityGroupEgress"
  ],
  "Resource": "*"
}
```

Scope down `iam:*` to specific paths: `${env}-${agent}*` roles only (least privilege).

---

## 10. Cost Considerations

### 10.1 OpenSearch Serverless

OpenSearch Serverless (AOSS) is the most significant cost driver.

| Component | Cost | Notes |
|-----------|------|-------|
| Indexing OCU | ~$0.24/OCU-hr, min 2 OCU | ~$350/month minimum |
| Search OCU | ~$0.24/OCU-hr, min 2 OCU | ~$350/month minimum |
| Storage | $0.024/GB/month | Negligible at KB scale |
| **Minimum total** | **~$700/month** | Per collection |

**Mitigation**: One shared collection across ALL agents. Each agent gets its own index (namespace) within the collection. This is the design adopted in the composition root - `create_opensearch_collection = true` only in the first agent's deployment (or at the shared infrastructure level). Subsequent agents pass `create_opensearch_collection = false` and provide the existing collection ARN.

**Recommended**: Extract the OpenSearch Serverless collection into a separate shared infrastructure module that is deployed once, and have the agent-platform module consume its ARN via a data source or variable.

### 10.2 ECS Fargate

| Environment | Strategy | Savings |
|-------------|----------|---------|
| dev, tst | Fargate Spot | ~70% vs on-demand |
| pst, prd | Fargate on-demand | Reliability over cost |

Non-prod savings estimate for PIA (1024 CPU + 512 CPU, 2048 + 1024 memory):
- On-demand: ~$65/month
- Fargate Spot: ~$20/month

### 10.3 Bedrock

Bedrock charges per inference token. No fixed monthly cost for Knowledge Base Retrieve operations at current volume. Monitor via CloudWatch `AWS/Bedrock` metrics.

### 10.4 Secrets Manager

$0.40/secret/month. PIA = 3 secrets = $1.20/month. Negligible.

### 10.5 Total Estimated Monthly (non-prod, 1 agent)

| Service | Cost |
|---------|------|
| OpenSearch Serverless (shared) | ~$700 |
| ECS Fargate Spot | ~$20 |
| S3 (KB bucket + state) | ~$2 |
| CloudWatch (dashboards + alarms) | ~$5 |
| Secrets Manager | ~$2 |
| **Total** | **~$730/month** |

The ~$700 OpenSearch floor dominates. Sharing across all future agents is critical.

---

## 11. Module Dependency Graph

```
┌──────────────────────────────────────────────────┐
│  Deployment Order (Terraform resolves via depends_on) │
└──────────────────────────────────────────────────┘

Phase 1 (no dependencies):
  s3-kb-bucket   → creates KB bucket
  secrets        → creates Secrets Manager entries

Phase 2 (depends on phase 1):
  iam            → needs s3-kb-bucket.bucket_arn, secrets.secret_arns_list

Phase 3 (depends on phase 2):
  bedrock-kb     → needs iam.bedrock_kb_role_arn, s3-kb-bucket.bucket_arn
  ecs-service    → needs iam.task_execution_role_arn, iam.task_role_arn,
                           secrets.secret_arns

Phase 4 (depends on phase 3):
  observability  → needs ecs-service.cluster_name, ecs-service.service_name,
                           bedrock-kb.knowledge_base_id

OpenSearch Serverless (composition root, before all modules):
  aws_opensearchserverless_collection.shared
  aws_opensearchserverless_security_policy.encryption
  aws_opensearchserverless_security_policy.network
  → iam.opensearch_collection_arn (all agents share)
```

Visual dependency graph:

```
[opensearch_collection]
        │
        ├──────────────────► [iam]
        │                      │
[s3-kb-bucket] ───────────────►│
                                │
[secrets] ─────────────────────►│
                                │
                    ┌───────────┼────────────┐
                    │           │            │
               [bedrock-kb] [ecs-service]   │
                    │           │            │
                    └───────────► [observability]
```

---

## 12. Testing Strategy

### 12.1 Terraform Validate (syntax + type checking)

Run against each module individually and the composition root:

```bash
# Validate all modules
for mod in ecs-service bedrock-kb secrets observability s3-kb-bucket iam; do
  echo "Validating $mod..."
  cd terraform/infrastructure/agent-platform/modules/$mod
  terraform init -backend=false
  terraform validate
  cd -
done

# Validate composition root
cd terraform/infrastructure/agent-platform
terraform init -backend=false
terraform validate
```

This is the gate in the reusable workflow's `terragrunt validate` step.

### 12.2 Terraform Plan (integration with real AWS)

Terragrunt plan against datanp account with PIA config. The plan should succeed with no errors, showing all resources to create.

```bash
cd terraform/infrastructure/agent-platform/environments/datanp/dev
terragrunt plan -out=plan.tfplan
```

Expected output:
- `Plan: N to add, 0 to change, 0 to destroy` on first run
- All resource names follow `dev-pia-*` convention
- No hardcoded values, no `PLACEHOLDER` strings in resource names

### 12.3 LocalStack (module unit tests)

LocalStack does not support Bedrock or OpenSearch Serverless, but can test the remaining modules:

`test/localstack/agent-platform/main.tf` - LocalStack test harness:

```hcl
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = "http://localhost:4566"
    iam            = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    logs           = "http://localhost:4566"
    ecs            = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    sns            = "http://localhost:4566"
  }
}

# Test s3-kb-bucket module
module "s3_kb_bucket" {
  source      = "../../../terraform/infrastructure/agent-platform/modules/s3-kb-bucket"
  agent_name  = "pia-test"
  environment = "test"
  project     = "agent-platform"
}

# Test secrets module
module "secrets" {
  source      = "../../../terraform/infrastructure/agent-platform/modules/secrets"
  agent_name  = "pia-test"
  environment = "test"
}
```

Assertions:
- `aws s3api head-bucket --bucket test-pia-test-kb-documents-*` returns 200
- `aws secretsmanager list-secrets --filters Key=name,Values=test/pia-test` returns 3 secrets
- `aws iam get-role --role-name test-pia-test-task-exec-role` returns the role

### 12.4 Acceptance Tests (post-deploy)

| Test | Method | Pass Criteria |
|------|--------|---------------|
| ECS health | `curl https://{alb}/ping` | HTTP 200 |
| Bedrock KB created | `aws bedrock-agent list-knowledge-bases` | KB visible |
| KB retrieval | `aws bedrock-agent-runtime retrieve` | Returns chunks |
| Secrets created | `aws secretsmanager list-secrets` | 3 secrets per agent |
| Dashboard renders | AWS Console CloudWatch | All widgets load |
| Alarms fire | `aws cloudwatch put-metric-data --namespace PIA/Agent --metric-name ErrorCount --value 10` | SNS notification |
| No public IPs | `aws ec2 describe-network-interfaces` on ECS tasks | No public IP assigned |

### 12.5 CI Validation Gate

The reusable workflow runs `terragrunt validate` before plan. For PRs, add a separate validation job that runs `terraform validate` on each module without a backend (using `terraform init -backend=false`). This can run on any non-prod runner without AWS credentials.

---

## 13. Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Shared OpenSearch collection | 1 collection, N indexes | Min $700/month per collection; sharing amortises cost |
| SSE-S3 for KB bucket | AES256 (not KMS) | Bedrock service principal can access without KMS key policy complexity |
| Fargate Spot (non-prod) | Enabled | ~70% cost savings; agents tolerate interruption in dev/tst |
| `ignore_changes` on secret_string | Lifecycle rule | Prevents Terraform from overwriting manually injected tokens |
| `ignore_changes` on ECS desired_count | Lifecycle rule | Allows manual scaling without Terraform reverting it |
| `for_each` over agent list | `local.agents_map` | Enables adding new agents with zero module changes |
| Socket Mode for Slack bot | No inbound port | Eliminates need for public endpoint; outbound WebSocket only |
| ALB host-header routing | `{agent}.{env}.internal` | Single ALB shared across agents; routes by hostname |
| Chunking: FIXED_SIZE 512 tokens 20% overlap | Default KB config | Reasonable default for runbook/incident documents; tunable post-deploy |

---

## 14. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| OpenSearch Serverless OCU spike during indexing | Medium | High ($) | Monitor OCU via CloudWatch; set billing alarm at $1000/month |
| Fargate Spot interruption in non-prod | High | Low | Tasks restart automatically; non-prod workloads are stateless |
| Secret placeholder not replaced before service start | High | High (service won't start) | Post-deploy runbook; Secrets Manager alarm on age if value contains "PLACEHOLDER" |
| Bedrock KB data source sync fails silently | Medium | Medium | Add sync job status alarm; use on-demand sync via API with error handling |
| OpenSearch index naming collision between agents | Low | High | Index name = `{env}-{agent}-index`; guaranteed unique by construction |
| GitHub OIDC role missing permissions | Medium | High | Test with dry-run plan in PR; enumerate all required permissions in IAM role |
| ALB listener rule priority conflict | Low | Medium | Use `priority = null` (auto-assigned); conflicts only if > 1000 rules |
| `dataprd` account ID placeholder in tfvars | High | High (deploy fails) | Placeholder documented clearly; validate step checks for `DATAPRD_ACCOUNT_ID` string |

---

## 15. Adding a Second Agent (Lex)

Per acceptance criterion 9, adding Lex requires only:

1. Add a new entry to `agents` in the environment tfvars:
```hcl
{
  name             = "lex"
  runtime_image    = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/lex-agent-runtime:latest"
  slack_bot_image  = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/lex-agent-slack-bot:latest"
  alarm_sns_emails = ["lex-alerts@pexa.com.au"]
}
```

2. Set `create_opensearch_collection = false` for Lex (collection already exists from PIA).

3. Create `deploy-lex-agent-platform.yml` caller workflow (copy of PIA caller, change paths).

No module changes required.

---
