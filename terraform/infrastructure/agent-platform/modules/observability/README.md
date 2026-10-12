# Module: observability

Creates a CloudWatch dashboard, metric alarms, and an SNS notification topic for an agent. Monitors error rate, P99 latency, and ECS running task count; alarm breaches send email notifications to the addresses specified in `alarm_sns_emails`. The metric namespace defaults to `<AGENT_NAME>/Agent` and can be overridden via `custom_metric_namespace`. This module is deployed for every agent regardless of which optional features are enabled.

## Usage

```hcl
module "observability" {
  source = "./modules/observability"

  agent_name   = "pia"
  environment  = "dev"

  ecs_cluster_name        = module.ecs_service.cluster_name
  ecs_service_name        = module.ecs_service.service_name
  alarm_sns_emails        = ["onedata-alerts-dev@pexa.com.au"]
  custom_metric_namespace = "PIA/Agent"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `agent_name` | Name of the agent | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `ecs_cluster_name` | ECS cluster name to monitor | `string` | — | yes |
| `ecs_service_name` | ECS service name to monitor | `string` | — | yes |
| `custom_metric_namespace` | Override CloudWatch metric namespace | `string` | `""` | no |
| `alarm_sns_emails` | Email addresses for alarm notifications | `list(string)` | `[]` | no |
| `error_rate_threshold` | Error count threshold for the alarm | `number` | `5` | no |
| `latency_p99_threshold` | P99 latency threshold in ms | `number` | `30000` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `sns_topic_arn` | ARN of the SNS alarms topic |
| `dashboard_name` | Name of the CloudWatch dashboard |
| `alarm_arns` | Map of alarm name to ARN |
