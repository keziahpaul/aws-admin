# AIRA — AI Request Intake Agent
locals {
  agent = {
    name            = "aira"
    container_image = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/dev-aira-agent-agent-runtime:latest"
    slack_bot_image = "042775015153.dkr.ecr.ap-southeast-2.amazonaws.com/dev-aira-agent-slack-bot:latest"

    # Form-driven agent with session memory for mid-conversation recovery
    enable_kb        = false
    enable_memory    = true
    enable_gateway   = false
    enable_slack_bot = true

    model_id = "au.anthropic.claude-sonnet-4-6"

    # Session memory: 7-day expiry (form sessions are short-lived)
    memory_expiry_days = 7
    memory_strategies = [
      {
        type       = "SEMANTIC"
        name       = "SessionStore"
        namespaces = ["/sessions/{actorId}/"]
      }
    ]

    # Dev: force-delete secrets on destroy (window 0) so destroy/recreate
    # cycles don't collide with the Secrets Manager recovery window.
    secret_recovery_window_days = 0

    # Secret names containing "slack" expect JSON with {token, app_token} keys
    # Other secrets map to env var via upper(replace(name, "-", "_"))
    secrets = {
      slack-bot      = { description = "Slack bot token and app-level token for Socket Mode" }
      signing-secret = { description = "Slack signing secret (SIGNING_SECRET)" }
      jira-email     = { description = "Jira API email (JIRA_EMAIL)" }
      jira-api-token = { description = "Jira API token (JIRA_API_TOKEN)" }
      agent-token    = { description = "Shared secret between bot and agent (AGENT_TOKEN)" }
    }

    alarm_sns_emails        = ["onedata-alerts-dev@pexa.com.au"]
    custom_metric_namespace = "AIRA/Agent"

    additional_environment_variables = {
      BEDROCK_MODEL_ID            = "au.anthropic.claude-sonnet-4-6"
      MAX_CLARIFICATION_QUESTIONS = "5"
      MAX_URLS_PER_FIELD          = "3"
      URL_FETCH_TIMEOUT           = "10"
      JIRA_SERVER                 = "https://pexa.atlassian.net"
      JIRA_PROJECT_KEY            = "DD"
      JIRA_ISSUE_TYPE             = "Story"
    }

    additional_iam_statements = [
      {
        sid       = "AgentCoreMemory"
        effect    = "Allow"
        actions   = ["bedrock-agentcore:BatchCreateMemoryRecords", "bedrock-agentcore:BatchDeleteMemoryRecords", "bedrock-agentcore:BatchUpdateMemoryRecords", "bedrock-agentcore:ListMemoryRecords", "bedrock-agentcore:GetMemoryRecord", "bedrock-agentcore:RetrieveMemoryRecords"]
        resources = ["arn:aws:bedrock-agentcore:ap-southeast-2:042775015153:memory/*"]
      },
    ]
  }
}
