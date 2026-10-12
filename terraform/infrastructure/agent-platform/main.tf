# ============================================================
# Composition root — Agent Platform
# Wires all per-agent modules together using for_each.
# ============================================================

# ------------------------------------------------------------------
# AWS context
# ------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "agent-platform"
  }

  # Primary index: agent name -> agent config object.
  # Agents with enable_agent = false are excluded entirely, so every
  # per-agent module (which derives its for_each from agents_map) tears the
  # agent's resources down. Flip the toggle back to true to recreate it.
  agents_map = { for a in var.agents : a.name => a if a.enable_agent }
}

# ------------------------------------------------------------------
# Shared OpenSearch Serverless collection (all KB-enabled agents share one)
# ------------------------------------------------------------------
resource "aws_opensearchserverless_security_policy" "encryption" {
  count = var.create_opensearch_collection ? 1 : 0

  name        = "${var.project}-${var.environment}-agent-platform-enc"
  type        = "encryption"
  description = "AWSOwnedKey encryption for agent-platform vector collection"

  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${var.project}-${var.environment}-agent-platform"]
    }]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  count = var.create_opensearch_collection ? 1 : 0

  name        = "${var.project}-${var.environment}-agent-platform-net"
  type        = "network"
  description = "Network policy for agent-platform vector collection (VPC access only)"

  policy = jsonencode([{
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${var.project}-${var.environment}-agent-platform"]
      }, {
      ResourceType = "dashboard"
      Resource     = ["collection/${var.project}-${var.environment}-agent-platform"]
    }]
    AllowFromPublic = true
  }])
}

resource "aws_opensearchserverless_collection" "shared" {
  count = var.create_opensearch_collection ? 1 : 0

  name = "${var.project}-${var.environment}-agent-platform"
  type = "VECTORSEARCH"

  tags = local.common_tags

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
  ]
}

# ------------------------------------------------------------------
# Module: IAM  (all agents)
# ------------------------------------------------------------------
module "iam" {
  for_each = local.agents_map
  source   = "./modules/iam"

  agent_name  = each.key
  environment = var.environment
  aws_region  = local.region
  account_id  = local.account_id

  kb_bucket_arn             = each.value.enable_kb ? module.s3_kb_bucket[each.key].bucket_arn : ""
  create_kb_role            = each.value.enable_kb
  opensearch_collection_arn = var.create_opensearch_collection && each.value.enable_kb ? aws_opensearchserverless_collection.shared[0].arn : ""
  secret_arns               = values(module.secrets[each.key].secret_arns)
  additional_iam_statements = each.value.additional_iam_statements
  tags                      = merge(local.common_tags, each.value.tags)
}

# ------------------------------------------------------------------
# Module: S3 KB bucket  (agents where enable_kb = true)
# ------------------------------------------------------------------
module "s3_kb_bucket" {
  for_each = { for k, v in local.agents_map : k => v if v.enable_kb }
  source   = "./modules/s3-kb-bucket"

  agent_name  = each.key
  environment = var.environment
  project     = var.project
  tags        = merge(local.common_tags, each.value.tags)
}

# ------------------------------------------------------------------
# Module: Secrets  (all agents)
# ------------------------------------------------------------------
module "secrets" {
  for_each = local.agents_map
  source   = "./modules/secrets"

  agent_name              = each.key
  environment             = var.environment
  secrets                 = each.value.secrets
  existing_secret_arns    = each.value.existing_secret_arns
  recovery_window_in_days = each.value.secret_recovery_window_days
  tags                    = merge(local.common_tags, each.value.tags)
}

# ------------------------------------------------------------------
# Module: AgentCore runtime  (all agents)
# ------------------------------------------------------------------
module "agent_runtime" {
  for_each = local.agents_map
  source   = "./modules/agent-runtime"

  agent_name         = each.key
  environment        = var.environment
  container_image    = each.value.container_image
  iam_role_arn       = module.iam[each.key].agentcore_runtime_role_arn
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids

  base_environment_variables = {
    AGENT_NAME  = each.key
    ENVIRONMENT = var.environment
    AWS_REGION  = local.region
    MODEL_ID    = each.value.model_id
  }
  additional_environment_variables = each.value.additional_environment_variables

  snapshot_retention_days = each.value.ecr_snapshot_retention_days
  release_image_count     = each.value.ecr_release_image_count
  untagged_retention_days = each.value.ecr_untagged_retention_days

  tags = merge(local.common_tags, each.value.tags)
}

# ------------------------------------------------------------------
# Module: ECS service / Slack bot  (agents where enable_slack_bot = true)
# ------------------------------------------------------------------
module "ecs_service" {
  for_each = { for k, v in local.agents_map : k => v if v.enable_slack_bot }
  source   = "./modules/ecs-service"

  agent_name         = each.key
  environment        = var.environment
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids

  runtime_arn             = module.agent_runtime[each.key].runtime_arn
  slack_bot_image         = each.value.slack_bot_image
  task_execution_role_arn = module.iam[each.key].task_execution_role_arn
  task_role_arn           = module.iam[each.key].task_role_arn
  secret_arns             = module.secrets[each.key].secret_arns

  kb_knowledge_base_id = each.value.enable_kb ? module.bedrock_kb[each.key].knowledge_base_id : ""
  memory_id            = each.value.enable_memory ? module.agent_memory[each.key].memory_id : ""
  memory_strategy_id   = each.value.enable_memory ? module.agent_memory[each.key].memory_strategy_id : ""
  desired_count        = each.value.slack_bot_desired_count
  cpu                  = each.value.slack_bot_cpu
  memory               = each.value.slack_bot_memory
  use_fargate_spot     = var.use_fargate_spot

  snapshot_retention_days = each.value.ecr_snapshot_retention_days
  release_image_count     = each.value.ecr_release_image_count
  untagged_retention_days = each.value.ecr_untagged_retention_days

  tags = merge(local.common_tags, each.value.tags)
}

# ------------------------------------------------------------------
# Module: Bedrock Knowledge Base  (agents where enable_kb = true)
# ------------------------------------------------------------------
module "bedrock_kb" {
  for_each = { for k, v in local.agents_map : k => v if v.enable_kb }
  source   = "./modules/bedrock-kb"

  agent_name     = each.key
  environment    = var.environment
  kb_bucket_arn  = module.s3_kb_bucket[each.key].bucket_arn
  kb_bucket_name = module.s3_kb_bucket[each.key].bucket_name
  kb_s3_prefix   = each.value.kb_s3_prefix

  opensearch_collection_arn         = aws_opensearchserverless_collection.shared[0].arn
  opensearch_collection_name        = aws_opensearchserverless_collection.shared[0].name
  additional_data_access_principals = ["arn:aws:iam::${local.account_id}:role/GitHubRunnerAgentPlatformDeploymentRole"]
  opensearch_collection_endpoint    = aws_opensearchserverless_collection.shared[0].collection_endpoint
  bedrock_kb_role_arn               = module.iam[each.key].bedrock_kb_role_arn

  chunking_strategy              = each.value.kb_chunking_strategy
  chunk_size                     = each.value.kb_chunk_size
  hierarchical_parent_chunk_size = try(each.value.kb_hierarchical_parent_chunk_size, 1500)
  hierarchical_child_chunk_size  = try(each.value.kb_hierarchical_child_chunk_size, 300)
  hierarchical_overlap_tokens    = try(each.value.kb_hierarchical_overlap_tokens, 60)
  parsing_strategy               = try(each.value.kb_parsing_strategy, "NONE")
  parsing_model_arn              = try(each.value.kb_parsing_model_arn, "")

  tags = merge(local.common_tags, each.value.tags)
}

# ------------------------------------------------------------------
# Module: AgentCore memory  (agents where enable_memory = true)
# ------------------------------------------------------------------
module "agent_memory" {
  for_each = { for k, v in local.agents_map : k => v if v.enable_memory }
  source   = "./modules/agent-memory"

  agent_name        = each.key
  environment       = var.environment
  event_expiry_days = each.value.memory_expiry_days
  memory_strategies = each.value.memory_strategies
  tags              = merge(local.common_tags, each.value.tags)
}

# ------------------------------------------------------------------
# Module: AgentCore gateway  (agents where enable_gateway = true)
# ------------------------------------------------------------------
module "agent_gateway" {
  for_each = { for k, v in local.agents_map : k => v if v.enable_gateway }
  source   = "./modules/agent-gateway"

  agent_name   = each.key
  environment  = var.environment
  instructions = each.value.gateway_instructions
  tags         = merge(local.common_tags, each.value.tags)
}

# ------------------------------------------------------------------
# Module: AgentCore scheduler  (agents where enable_scheduler = true)
# ------------------------------------------------------------------
module "agent_scheduler" {
  for_each = { for k, v in local.agents_map : k => v if v.enable_scheduler }
  source   = "./modules/agent-scheduler"

  agent_name          = each.key
  environment         = var.environment
  runtime_arn         = module.agent_runtime[each.key].runtime_arn
  schedule_expression = each.value.scheduler_expression
  payload             = each.value.scheduler_payload
  tags                = merge(local.common_tags, each.value.tags)
}

# ------------------------------------------------------------------
# Module: Observability  (all agents)
# ------------------------------------------------------------------
module "observability" {
  for_each = local.agents_map
  source   = "./modules/observability"

  agent_name  = each.key
  environment = var.environment

  # Cluster and service names are only meaningful when the Slack bot (ECS service) is enabled.
  # Pass empty strings for non-ECS agents so the module can handle them gracefully.
  ecs_cluster_name = each.value.enable_slack_bot ? module.ecs_service[each.key].cluster_name : ""
  ecs_service_name = each.value.enable_slack_bot ? module.ecs_service[each.key].service_name : ""

  alarm_sns_emails        = each.value.alarm_sns_emails
  custom_metric_namespace = each.value.custom_metric_namespace

  tags = merge(local.common_tags, each.value.tags)
}
