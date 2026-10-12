# DMS CloudWatch Logs Subscription Filters

This Terraform module creates CloudWatch Logs subscription filters for DMS replication tasks to stream logs to Splunk via Kinesis Firehose.

## Overview

DMS automatically creates CloudWatch log groups when logging is enabled in the replication configuration. This module constructs log group names from the provided DMS task IDs using a static naming pattern and creates subscription filters to forward logs to the Firehose delivery stream managed by the Splunk team.

## How It Works

1. **Log Group Name Construction**: For each provided DMS task ID, constructs the corresponding log group name using the static pattern.
2. **Creation**: Creates a subscription filter for each constructed log group using `for_each`.

This approach handles:
- Multiple DMS tasks in the same environment
- Consistent log group naming based on task IDs
- Tasks added/removed over time (update the list of task IDs and re-run terraform to sync)

## Prerequisites

1. DMS replication task must be deployed (via CloudFormation)
2. DMS logging must be enabled (creates log groups automatically)
3. Splunk team must have created:
   - Kinesis Firehose delivery stream
   - IAM role for CloudWatch Logs subscription filter

## Log Group Naming Convention

DMS creates log groups with the pattern:
```
dms-tasks-{replication-config-identifier}
```

Examples:
- `dms-tasks-tst-onedata-projects-serverless-full-cdc`
- `dms-tasks-tst-onedata-exchange-serverless-full-cdc`
- `dms-tasks-dev-onedata-projects-serverless-full-cdc`

## Configuration

### Required Variables

- `environment`: Environment name (dev, tst, pst, prd)
- `firehose_delivery_stream_arn`: ARN provided by Splunk team
- `subscription_filter_role_arn`: IAM role ARN provided by Splunk team

### Optional Variables

- `log_group_prefix`: Prefix to search for log groups (default: `"dms-tasks-"`)
- `log_group_pattern`: Regex to filter discovered log groups (default: `""` - no filtering)

### Example Configuration

```hcl
inputs = {
  environment                  = "tst"
  dms_task_ids                 = ["tst-onedata-projects-serverless-full-cdc", "tst-onedata-exchange-serverless-full-cdc"] # Only TST environment tasks
  log_group_pattern            = ".*onedata.*"           # Only onedata-related tasks
  firehose_delivery_stream_arn = "arn:aws:firehose:..."
  subscription_filter_role_arn = "arn:aws:iam::..."
}
```

### Filtering Examples

| Prefix | Pattern | Result |
|--------|---------|--------|
| `dms-tasks-` | `""` | All DMS tasks in account |
| `dms-tasks-tst-` | `""` | All TST environment tasks |
| `dms-tasks-tst-` | `.*onedata-projects.*` | Only TST onedata-projects tasks |
| `dms-tasks-` | `.*serverless-full-cdc$` | Only full-cdc tasks (all envs) |

## Usage

### Deploy to TST Environment

```bash
cd terraform/infrastructure/dms-cw-subscription-filters/environments/digitalnp/tst
terragrunt init
terragrunt plan
terragrunt apply
```

### Verify Discovered Log Groups

```bash
# See what log groups were discovered
terragrunt output log_groups_discovered

# See what log groups matched the filter
terragrunt output log_groups_monitored

# See subscription filters created
terragrunt output subscription_filter_names
```

### Verify Subscription Filters in AWS

```bash
# List all subscription filters for a log group
aws logs describe-subscription-filters \
  --log-group-name dms-tasks-tst-onedata-projects-serverless-full-cdc \
  --region ap-southeast-2
```

## Resources Created

- `aws_cloudwatch_log_subscription_filter.dms_task_logs[*]`: One subscription filter per discovered log group

## Outputs

- `subscription_filter_names`: Map of log group name to subscription filter name
- `log_groups_monitored`: List of log groups with subscription filters
- `log_groups_discovered`: All log groups found (before filtering)
- `subscription_filter_count`: Number of subscription filters created

## Adding New DMS Tasks

When new DMS tasks are added:

1. DMS creates new log group automatically
2. Re-run `terragrunt apply` to discover and add subscription filter
3. No code changes needed

## Removing DMS Tasks

When DMS tasks are removed:

1. Log group may remain (manual cleanup)
2. Re-run `terragrunt apply` to remove orphaned subscription filters
3. Terraform will detect and remove filters for non-existent log groups

## Notes

- This module does NOT modify the existing CloudFormation DMS stack
- Subscription filters are independent resources that reference log groups
- One subscription filter per log group (DMS task)
- Filter pattern is empty ("") to capture all log events
- Log group discovery happens at `terraform plan` time
