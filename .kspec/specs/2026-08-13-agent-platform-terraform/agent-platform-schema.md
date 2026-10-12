# Agent Platform YAML Schema — `agent-platform.yaml`

**Purpose**: Declarative configuration file placed in each agent repo. Our Terraform reads this to decide which shared modules to instantiate. Designed to map 1:1 to PIDP's `pidp.yaml` `capabilities` block when we migrate.

---

## Example: PIA Agent

```yaml
# pexa-pia-agent/agent-platform.yaml
---
version: 1
agent:
  name: pia-agent
  product: onedata
  domain: exchange
  description: "PEXA Incident Assistant — operational impact assessment via Slack"
  team: onedata@pexa.com.au

runtime:
  networkMode: VPC
  modelId: "au.anthropic.claude-opus-4"
  idleTimeout: 1800
  maxLifetime: 3600

capabilities:
  slackBot:
    enabled: true
    desiredCount: 1
    cpu: 256
    memory: 512

  knowledgeBase:
    enabled: true
    embeddingModel: "amazon.titan-embed-text-v2:0"
    chunkingStrategy: HIERARCHICAL
    chunkSize: 1500
    overlapSize: 300

  gateway:
    enabled: true
    instructions: "PIA tools: Prisma AIRS MCP for security enrichment"

  memory:
    enabled: true
    expiryDays: 90
    strategies:
      - type: semantic
        name: IncidentTracker
        namespace: "/incidents/{actorId}/"

  secrets:
    enabled: true
    entries:
      - name: slack-bot
        description: "Slack bot token + app token JSON"

  s3:
    enabled: true
    buckets:
      - name: kb-data
        purpose: knowledge-base-source
        versioning: true

  observability:
    enabled: true
    namespace: "PIA/Agent"
    dashboard: true
    alarms:
      errorRateThreshold: 5
      latencyP99Threshold: 30000
      unhealthyTaskAlarm: true
    alarmEmails:
      - onedata@pexa.com.au

  scheduler:
    enabled: false

environments:
  datanp:
    dev:
      runtime:
        modelId: "au.anthropic.claude-sonnet-4-6"
      env:
        KNOWLEDGE_BASE_ID: "TBD"
        SUPERVISOR_MODEL_ID: "au.anthropic.claude-sonnet-4-6"
        SLACK_CHANNEL: "#pia-dev"
    tst:
      env:
        KNOWLEDGE_BASE_ID: "TBD"
        SUPERVISOR_MODEL_ID: "au.anthropic.claude-opus-4"
  dataprd:
    prd:
      slackBot:
        desiredCount: 2
      env:
        KNOWLEDGE_BASE_ID: "TBD"
        SUPERVISOR_MODEL_ID: "au.anthropic.claude-opus-4"
        SLACK_CHANNEL: "#pexa-incident-comms-internal"
```

---

## Example: Vulnerability Agent

```yaml
# pexa-one-data-vulnerability-agent/agent-platform.yaml
---
version: 1
agent:
  name: vuln-agent
  product: onedata
  domain: security
  description: "Automated vulnerability advisory generation from Nucleus findings"
  team: onedata@pexa.com.au

runtime:
  networkMode: VPC
  modelId: "au.anthropic.claude-sonnet-4-6"
  idleTimeout: 300
  maxLifetime: 3600

capabilities:
  slackBot:
    enabled: true
    desiredCount: 1
    cpu: 256
    memory: 512

  knowledgeBase:
    enabled: false

  gateway:
    enabled: true
    instructions: "Vulnerability tools: Nucleus, Slack, Jira"

  memory:
    enabled: true
    expiryDays: 90
    strategies:
      - type: semantic
        name: NotificationTracker
        namespace: "/notifications/{actorId}/"
      - type: summary
        name: RunSummarizer
        namespace: "/summaries/{actorId}/{sessionId}/"

  secrets:
    enabled: true
    entries:
      - name: nucleus
        description: "Nucleus API key"
      - name: cortex-xdr
        description: "Cortex XDR API credentials"
      - name: github-app
        description: "GitHub App private key"
    existing:
      - name: slack
        arn: "arn:aws:secretsmanager:ap-southeast-2:042775015153:secret:onedata-vuln-agent-dev-slack-*"

  s3:
    enabled: false

  observability:
    enabled: true
    namespace: "VulnAgent/Security"
    dashboard: true
    alarms:
      errorRateThreshold: 10
      latencyP99Threshold: 90000
      unhealthyTaskAlarm: true

  scheduler:
    enabled: true
    schedule: "cron(0 12 * * ? *)"
    payload:
      input:
        prompt: "Run nightly vulnerability scan"
        limit: 0

environments:
  datanp:
    dev:
      env:
        AGENT_MODE: "pipeline"
        NUCLEUS_BASE_URL: "https://nucleus.internal"
        SLACK_CHANNEL_DEFAULT: "#od-shield-dev"
```

---

## Example: Lex (Compliance Agent)

```yaml
# pexa-one-data-compliance-agent/agent-platform.yaml
---
version: 1
agent:
  name: compliance-agent
  product: onedata
  domain: compliance
  description: "AI compliance assistant for PEXA separation and regulatory questions"
  team: onedata@pexa.com.au

runtime:
  networkMode: VPC
  modelId: "au.anthropic.claude-sonnet-4-6"
  idleTimeout: 1800
  maxLifetime: 3600

capabilities:
  slackBot:
    enabled: true
    desiredCount: 2
    cpu: 256
    memory: 512

  knowledgeBase:
    enabled: false  # Pre-existing, ID passed via env var
    # existingId: "MALSFASBSB"  # Reference only, not created

  gateway:
    enabled: false

  memory:
    enabled: false

  secrets:
    enabled: true
    entries:
      - name: slack-bot
        description: "Slack bot + app token JSON"

  s3:
    enabled: false  # KB bucket pre-exists

  observability:
    enabled: true
    namespace: "Lex/Compliance"
    dashboard: true
    alarms:
      errorRateThreshold: 5
      latencyP99Threshold: 30000
      unhealthyTaskAlarm: true

  scheduler:
    enabled: false

environments:
  datanp:
    dev:
      env:
        KNOWLEDGE_BASE_ID: "MALSFASBSB"
        SUPERVISOR_MODEL_ID: "au.anthropic.claude-sonnet-4-6"
```

---

## Schema Reference

### Root

| Field | Required | Description |
|-------|----------|-------------|
| `version` | Yes | Schema version (currently `1`) |
| `agent` | Yes | Agent identity |
| `runtime` | Yes | AgentCore runtime config |
| `capabilities` | Yes | What platform modules to enable |
| `environments` | No | Per-environment overrides |

### `agent`

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Agent identifier (used in resource naming) |
| `product` | Yes | Product grouping (`onedata`, `gap`, etc.) |
| `domain` | No | Domain area (`exchange`, `security`, `compliance`) |
| `description` | No | Human-readable description |
| `team` | No | Team email for ownership |

### `runtime`

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `networkMode` | No | `VPC` | `VPC` or `PUBLIC` |
| `modelId` | No | — | Default Bedrock model inference profile |
| `idleTimeout` | No | `1800` | Seconds before idle session is killed |
| `maxLifetime` | No | `3600` | Max session lifetime in seconds |

### `capabilities.slackBot`

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `enabled` | Yes | — | Create ECS Fargate Slack bot |
| `desiredCount` | No | `1` | Number of tasks (2 for HA) |
| `cpu` | No | `256` | Fargate CPU units |
| `memory` | No | `512` | Fargate memory MB |

### `capabilities.knowledgeBase`

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `enabled` | Yes | — | Create Bedrock KB + AOSS + S3 |
| `embeddingModel` | No | `amazon.titan-embed-text-v2:0` | Embedding model |
| `chunkingStrategy` | No | `FIXED_SIZE` | `FIXED_SIZE`, `HIERARCHICAL`, `SEMANTIC` |
| `chunkSize` | No | `512` | Chunk size in tokens |
| `overlapSize` | No | `60` | Overlap between chunks |
| `existingAossArn` | No | — | Share existing AOSS collection (cost saving) |

### `capabilities.gateway`

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `enabled` | Yes | — | Create AgentCore Gateway |
| `instructions` | No | — | Gateway-level tool description |

### `capabilities.memory`

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `enabled` | Yes | — | Create AgentCore Memory |
| `expiryDays` | No | `90` | Event TTL in days |
| `strategies` | No | `[]` | List of memory strategy configs |
| `strategies[].type` | Yes | — | `semantic` or `summary` |
| `strategies[].name` | Yes | — | Strategy name |
| `strategies[].namespace` | Yes | — | Namespace template pattern |

### `capabilities.secrets`

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `enabled` | Yes | — | Manage secrets |
| `entries` | No | `[]` | Secrets to CREATE (values injected out-of-band) |
| `entries[].name` | Yes | — | Secret name suffix |
| `entries[].description` | No | — | Description |
| `existing` | No | `[]` | BYO secrets (just reference ARN, don't create) |
| `existing[].name` | Yes | — | Logical name |
| `existing[].arn` | Yes | — | Full ARN or ARN pattern |

### `capabilities.s3`

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `enabled` | Yes | — | Create S3 bucket(s) |
| `buckets` | No | `[]` | List of buckets |
| `buckets[].name` | Yes | — | Bucket name suffix |
| `buckets[].purpose` | No | — | `knowledge-base-source`, `artifacts`, etc. |
| `buckets[].versioning` | No | `true` | Enable versioning |

### `capabilities.observability`

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `enabled` | Yes | — | Create dashboard + alarms |
| `namespace` | No | `{Agent}/{Name}` | Custom CloudWatch metric namespace |
| `dashboard` | No | `true` | Create CloudWatch dashboard |
| `alarms.errorRateThreshold` | No | `5` | Error rate % threshold |
| `alarms.latencyP99Threshold` | No | `30000` | P99 latency ms threshold |
| `alarms.unhealthyTaskAlarm` | No | `true` | ECS unhealthy task alarm |
| `alarmEmails` | No | `[]` | SNS notification emails |

### `capabilities.scheduler`

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `enabled` | Yes | — | Create EventBridge schedule |
| `schedule` | No | — | Cron or rate expression |
| `payload` | No | `{}` | JSON payload to send to runtime |

### `environments`

Per-account, per-environment overrides. Anything in `capabilities` or `runtime` can be overridden here.

```yaml
environments:
  datanp:           # AWS account alias
    dev:            # Environment name
      runtime:      # Override runtime settings
        modelId: "..."
      slackBot:     # Override capability settings
        desiredCount: 1
      env:          # Environment variables injected into runtime
        KEY: "value"
  dataprd:
    prd:
      slackBot:
        desiredCount: 2
      env:
        KEY: "prod-value"
```

---

## How Terraform Reads This

```hcl
# terraform/main.tf in agent repo
locals {
  config = yamldecode(file("${path.root}/../agent-platform.yaml"))
  env    = local.config.environments[var.account][var.environment]
  caps   = local.config.capabilities
}

module "runtime" {
  source = "git::...//terraform/modules/agent-runtime?ref=v1.0"
  agent_name  = local.config.agent.name
  environment = var.environment
  # ...
}

module "slack_bot" {
  count  = try(local.caps.slackBot.enabled, false) ? 1 : 0
  source = "git::...//terraform/modules/agent-slack-bot?ref=v1.0"
  desired_count = try(local.env.slackBot.desiredCount, local.caps.slackBot.desiredCount, 1)
  # ...
}

module "kb" {
  count  = try(local.caps.knowledgeBase.enabled, false) ? 1 : 0
  source = "git::...//terraform/modules/agent-bedrock-kb?ref=v1.0"
  # ...
}

# ... etc for each capability
```

---

## Migration Path to PIDP

When PIDP adds AgentCore capabilities, the mapping is direct:

| `agent-platform.yaml` | `pidp.yaml` equivalent |
|----------------------|----------------------|
| `agent.name` | `name` |
| `agent.product` | `product` |
| `runtime.networkMode` | `agentcore.networkMode` |
| `capabilities.slackBot` | `capabilities.agentcore.slackBot` (new) |
| `capabilities.knowledgeBase` | `capabilities.agentcore.knowledgeBase` (new) |
| `capabilities.gateway` | `capabilities.agentcore.gateway` (new) |
| `capabilities.memory` | `capabilities.agentcore.memory` (new) |
| `capabilities.secrets` | `capabilities.secrets` (already exists) |
| `capabilities.s3` | `capabilities.s3` (already exists) |
| `capabilities.scheduler` | `capabilities.agentcore.scheduler` (new) |
| `environments.datanp.dev.env` | `environments.{cluster}.dev.config.env` (already exists) |

A migration script would be ~50 lines of Python to transform one YAML to the other.

---

*Schema version 1. Designed for forward-compatibility with PIDP `pidp.yaml` capabilities model.*
