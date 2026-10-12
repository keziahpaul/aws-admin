# Module: agent-memory

Provisions an AWS Bedrock AgentCore memory store for an agent, enabling persistent cross-session memory. Memory strategies define how events are stored and namespaced (e.g., per-user incident history). Events are automatically expired after `event_expiry_days` to control storage costs and data retention. This module is only needed when `enable_memory = true`.

## Usage

```hcl
module "agent_memory" {
  source = "./modules/agent-memory"

  agent_name        = "pia"
  environment       = "dev"
  event_expiry_days = 90

  memory_strategies = [
    {
      type       = "semantic"
      name       = "IncidentTracker"
      namespaces = ["/incidents/{actorId}/"]
    }
  ]
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `agent_name` | Name of the agent | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `event_expiry_days` | Days before memory events expire | `number` | `90` | no |
| `memory_strategies` | List of memory strategy configurations | `list(object)` | `[]` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `memory_id` | ID of the AgentCore memory store |
| `memory_arn` | ARN of the AgentCore memory store |
