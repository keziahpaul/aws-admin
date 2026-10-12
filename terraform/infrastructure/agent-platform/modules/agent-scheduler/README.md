# Module: agent-scheduler

Provisions an EventBridge Scheduler rule and a Lambda function that invokes an AgentCore runtime on a schedule. The Lambda proxies the scheduler payload to the runtime, enabling background batch jobs (e.g., nightly incident summary generation). Schedule expressions support both `rate()` and `cron()` syntax. This module is only needed when `enable_scheduler = true`.

## Usage

```hcl
module "agent_scheduler" {
  source = "./modules/agent-scheduler"

  agent_name          = "pia"
  environment         = "dev"
  runtime_arn         = module.agent_runtime.runtime_arn
  schedule_expression = "cron(0 18 * * ? *)"
  schedule_timezone   = "Australia/Melbourne"

  payload = {
    task = "nightly-summary"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `agent_name` | Name of the agent | `string` | — | yes |
| `environment` | Deployment environment | `string` | — | yes |
| `runtime_arn` | AgentCore runtime ARN to invoke | `string` | — | yes |
| `schedule_expression` | EventBridge schedule expression | `string` | — | yes |
| `schedule_timezone` | IANA timezone for the schedule | `string` | `"UTC"` | no |
| `payload` | Key-value payload sent to the runtime | `map(string)` | `{}` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `schedule_arn` | ARN of the EventBridge schedule |
| `lambda_function_arn` | ARN of the Lambda trigger function |
