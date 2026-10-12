locals {
  memory_name = replace("${var.environment}_${var.agent_name}_memory", "-", "_")
}

# --- AgentCore Memory Store ---

resource "aws_bedrockagentcore_memory" "this" {
  name                  = local.memory_name
  description           = "Memory store for ${var.agent_name} agent"
  event_expiry_duration = var.event_expiry_days

  tags = var.tags
}

# --- Memory Strategies ---

resource "aws_bedrockagentcore_memory_strategy" "this" {
  for_each = {
    for s in var.memory_strategies : s.name => s
  }

  memory_id           = aws_bedrockagentcore_memory.this.id
  name                = each.value.name
  type                = each.value.type
  namespace_templates = each.value.namespaces
}
