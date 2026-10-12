locals {
  name_prefix = "${var.environment}-${var.agent_name}-agent"
}

# --- IAM Role for AgentCore Gateway ---

resource "aws_iam_role" "gateway" {
  name = "${local.name_prefix}-agentcore-gateway"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "bedrock-agentcore.amazonaws.com" }
    }]
  })

  tags = var.tags
}

# --- AgentCore Gateway ---

resource "aws_bedrockagentcore_gateway" "this" {
  name            = "${local.name_prefix}-gateway"
  authorizer_type = var.authorizer_type
  protocol_type   = "MCP"
  role_arn        = aws_iam_role.gateway.arn

  protocol_configuration {
    mcp {
      instructions = var.instructions
    }
  }

  tags = var.tags
}

# --- Gateway Targets (optional) ---
# NOTE: target_configuration is complex and varies per target type (MCP, HTTP, Lambda).
# This module creates the gateway resource. For target registration, teams should use
# the aws_bedrockagentcore_gateway_target resource directly in their agent layer,
# or we can extend this module once target patterns stabilise.
