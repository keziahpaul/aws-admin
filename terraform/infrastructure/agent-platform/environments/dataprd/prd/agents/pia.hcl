# PIA — PEXA Incident Assistant (prd)
locals {
  agent = {
    name            = "pia"
    container_image = "DATAPRD_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/prd-pia-agent-runtime:prd"
    slack_bot_image = "DATAPRD_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/prd-pia-agent-slack-bot:prd"

    # Production: higher CPU/memory for consistent latency
    runtime_cpu    = 2048
    runtime_memory = 4096
    slack_bot_cpu    = 512
    slack_bot_memory = 1024
    slack_bot_desired_count = 2

    enable_kb        = true
    enable_memory    = true
    enable_gateway   = true
    enable_slack_bot = true

    model_id = "au.anthropic.claude-sonnet-4-6"

    secrets = {
      slack-bot = { description = "Slack bot + app token" }
    }

    alarm_sns_emails        = ["onedata-alerts-prd@pexa.com.au"]
    custom_metric_namespace = "PIA/Agent"

    kb_chunking_strategy = "HIERARCHICAL"
    kb_chunk_size        = 1500

    gateway_instructions = "PIA tools: Prisma AIRS MCP"

    memory_strategies = [
      {
        type       = "SEMANTIC"
        name       = "IncidentTracker"
        namespaces = ["/incidents/{actorId}/"]
      }
    ]

    additional_iam_statements = [
      {
        sid       = "BedrockRetrieve"
        effect    = "Allow"
        actions   = ["bedrock:Retrieve", "bedrock:RetrieveAndGenerate"]
        resources = ["arn:aws:bedrock:ap-southeast-2:DATAPRD_ACCOUNT_ID:knowledge-base/*"]
      },
    ]
  }
}
