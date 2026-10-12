# PIA — PEXA Incident Assistant
locals {
  agent = {
    name            = "pia"
    container_image = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/dev-pia-agent-agent-runtime:latest"
    slack_bot_image = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/dev-pia-agent-slack-bot:latest"

    enable_kb        = true
    enable_memory    = true
    enable_gateway   = true
    enable_slack_bot = true

    model_id = "au.anthropic.claude-sonnet-4-6"

    secrets = {
      slack-bot = { description = "Slack bot + app token" }
    }

    alarm_sns_emails        = ["onedata-alerts-dev@pexa.com.au"]
    custom_metric_namespace = "PIA/Agent"

    kb_chunking_strategy = "HIERARCHICAL"
    kb_chunk_size        = 1500
    kb_parsing_strategy  = "BEDROCK_FOUNDATION_MODEL"
    kb_parsing_model_arn = "arn:aws:bedrock:ap-southeast-2:042775015153:inference-profile/au.anthropic.claude-sonnet-4-6"

    gateway_instructions = "PIA tools: Prisma AIRS MCP"

    memory_strategies = [
      {
        type       = "SEMANTIC"
        name       = "IncidentTracker"
        namespaces = ["/incidents/{actorId}/"]
      }
    ]

    additional_environment_variables = {
      KB_ID               = "PR6NTB5SHM"
      SUPERVISOR_MODEL_ID = "au.anthropic.claude-sonnet-4-6"
      KNOWLEDGE_BASE_ID   = "PR6NTB5SHM"
    }

    additional_iam_statements = [
      {
        sid       = "BedrockRetrieve"
        effect    = "Allow"
        actions   = ["bedrock:Retrieve", "bedrock:RetrieveAndGenerate"]
        resources = ["arn:aws:bedrock:ap-southeast-2:042775015153:knowledge-base/*"]
      },
      {
        sid       = "AgentCoreMemory"
        effect    = "Allow"
        actions   = ["bedrock-agentcore:BatchCreateMemoryRecords", "bedrock-agentcore:BatchDeleteMemoryRecords", "bedrock-agentcore:BatchUpdateMemoryRecords", "bedrock-agentcore:ListMemoryRecords", "bedrock-agentcore:GetMemoryRecord", "bedrock-agentcore:RetrieveMemoryRecords"]
        resources = ["arn:aws:bedrock-agentcore:ap-southeast-2:042775015153:memory/*"]
      },
    ]
  }
}
