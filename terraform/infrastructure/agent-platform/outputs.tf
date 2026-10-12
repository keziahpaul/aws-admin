# ============================================================
# Outputs — Agent Platform composition root
# Per-agent maps keyed by agent name.
# ============================================================

output "agents" {
  description = "Per-agent output map. Keys are agent names."
  value = {
    for k, v in local.agents_map : k => {
      # IAM
      task_execution_role_arn = module.iam[k].task_execution_role_arn
      task_role_arn           = module.iam[k].task_role_arn
      bedrock_kb_role_arn     = module.iam[k].bedrock_kb_role_arn

      # Secrets
      secret_arns = module.secrets[k].secret_arns

      # Runtime
      runtime_arn      = module.agent_runtime[k].runtime_arn
      runtime_id       = module.agent_runtime[k].runtime_id
      ecr_runtime_url  = module.agent_runtime[k].ecr_repository_url

      # ECS / Slack bot (empty when not enabled)
      ecs_cluster_name  = v.enable_slack_bot ? module.ecs_service[k].cluster_name : ""
      ecs_service_name  = v.enable_slack_bot ? module.ecs_service[k].service_name : ""
      ecr_slack_bot_url = v.enable_slack_bot ? module.ecs_service[k].ecr_repository_url : ""

      # Knowledge Base (empty when not enabled)
      kb_bucket_name     = v.enable_kb ? module.s3_kb_bucket[k].bucket_name : ""
      kb_bucket_arn      = v.enable_kb ? module.s3_kb_bucket[k].bucket_arn : ""
      knowledge_base_id  = v.enable_kb ? module.bedrock_kb[k].knowledge_base_id : ""
      knowledge_base_arn = v.enable_kb ? module.bedrock_kb[k].knowledge_base_arn : ""

      # Memory (empty when not enabled)
      memory_id  = v.enable_memory ? module.agent_memory[k].memory_id : ""
      memory_arn = v.enable_memory ? module.agent_memory[k].memory_arn : ""

      # Gateway (empty when not enabled)
      gateway_id  = v.enable_gateway ? module.agent_gateway[k].gateway_id : ""
      gateway_arn = v.enable_gateway ? module.agent_gateway[k].gateway_arn : ""

      # Scheduler (empty when not enabled)
      schedule_arn = v.enable_scheduler ? module.agent_scheduler[k].schedule_arn : ""

      # Observability
      sns_topic_arn  = module.observability[k].sns_topic_arn
      dashboard_name = module.observability[k].dashboard_name
    }
  }
}

output "opensearch_collection_arn" {
  description = "ARN of the shared OpenSearch Serverless collection (empty when create_opensearch_collection = false)"
  value       = var.create_opensearch_collection ? aws_opensearchserverless_collection.shared[0].arn : ""
}

output "opensearch_collection_endpoint" {
  description = "HTTPS endpoint of the shared OpenSearch Serverless collection (empty when create_opensearch_collection = false)"
  value       = var.create_opensearch_collection ? aws_opensearchserverless_collection.shared[0].collection_endpoint : ""
}
