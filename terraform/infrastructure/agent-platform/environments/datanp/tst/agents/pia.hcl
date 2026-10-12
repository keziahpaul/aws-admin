# PIA — PEXA Incident Assistant (tst)
locals {
  agent = {
    name            = "pia"
    container_image = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/tst-pia-agent-runtime:tst"
    slack_bot_image = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/tst-pia-agent-slack-bot:tst"

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
        resources = ["arn:aws:bedrock:ap-southeast-2:042775015153:knowledge-base/*"]
      },
    ]
  }
}
