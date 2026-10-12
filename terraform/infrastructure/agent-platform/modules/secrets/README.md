# Module: secrets

Manages AWS Secrets Manager secrets for an agent. Supports two modes: creating new secrets (via the `secrets` map) and referencing existing secrets by ARN (via `existing_secret_arns`). Both sets are merged into a single unified output map so downstream modules do not need to distinguish between origins. Secret values are not set by this module — they must be populated manually or via a separate rotation mechanism.

## Usage

```hcl
module "secrets" {
  source = "./modules/secrets"

  agent_name  = "pia"
  environment = "dev"

  secrets = {
    slack-bot = { description = "Slack bot + app token" }
  }

  existing_secret_arns = {
    third-party-api = "arn:aws:secretsmanager:ap-southeast-2:042775015153:secret:my-existing-secret"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `agent_name` | Name of the agent | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `secrets` | Map of secrets to create (key = short name) | `map(object)` | `{}` | no |
| `existing_secret_arns` | Map of existing secret ARNs to reference | `map(string)` | `{}` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `secret_arns` | Map of logical name to secret ARN (created + existing) |
| `secret_arns_list` | Flat list of all secret ARNs |
