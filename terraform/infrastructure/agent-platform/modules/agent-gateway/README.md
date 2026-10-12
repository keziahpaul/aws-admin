# Module: agent-gateway

Creates a Bedrock AgentCore gateway that exposes MCP tool endpoints for an agent. The gateway acts as a managed ingress point for tool integrations (e.g., Prisma AIRS MCP) and uses AWS IAM as the default authorizer. Gateway targets define the external MCP endpoints the gateway will route to. This module is only needed when `enable_gateway = true`.

## Usage

```hcl
module "agent_gateway" {
  source = "./modules/agent-gateway"

  agent_name   = "pia"
  environment  = "dev"
  instructions = "PIA tools: Prisma AIRS MCP"

  gateway_targets = [
    {
      name          = "prisma-airs"
      description   = "Prisma AIRS MCP endpoint"
      endpoint_type = "MCP"
      endpoint_uri  = "https://airs.mcp.example.com"
    }
  ]
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `agent_name` | Name of the agent | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `instructions` | Gateway instructions / tool description | `string` | `""` | no |
| `authorizer_type` | Gateway authorizer type | `string` | `"AWS_IAM"` | no |
| `gateway_targets` | List of gateway target configurations | `list(object)` | `[]` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `gateway_id` | ID of the AgentCore gateway |
| `gateway_arn` | ARN of the AgentCore gateway |
| `gateway_role_arn` | ARN of the IAM role used by the gateway |
