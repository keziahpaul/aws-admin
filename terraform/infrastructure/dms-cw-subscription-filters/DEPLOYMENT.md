# Deployment Guide: DMS CloudWatch Subscription Filters

## Context

The Splunk team has created Kinesis Firehose delivery streams and IAM roles in each account to ingest CloudWatch logs. This module creates subscription filters on DMS CloudWatch log groups to forward logs to Splunk.

## Resources Provided by Splunk Team

For **TST environment (Account: 570723136177)**:
- Firehose Stream: `arn:aws:firehose:ap-southeast-2:570723136177:deliverystream/tst-onedata-projects-firehose-delivery-stream`
- IAM Role: `arn:aws:iam::570723136177:role/tst-onedata-projects-CWLogsSubFilterIAMRole`

## IAM Role Requirements

The GitHub Actions workflow uses the existing `GitHubRunnerPEXAOneDataRole`. This role needs additional permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchLogsSubscriptionFilters",
      "Effect": "Allow",
      "Action": [
        "logs:PutSubscriptionFilter",
        "logs:DescribeSubscriptionFilters",
        "logs:DeleteSubscriptionFilter"
      ],
      "Resource": "arn:aws:logs:ap-southeast-2:*:log-group:dms-tasks-*"
    },
    {
      "Sid": "PassRoleToSubscriptionFilter",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::*:role/*-CWLogsSubFilterIAMRole"
    }
  ]
}
```

**Note**: Add this policy to `GitHubRunnerPEXAOneDataRole` in each account before deploying.

## Step-by-Step Deployment

### 1. Verify DMS Log Groups Exist

The module will automatically discover log groups, but you can verify they exist:

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "dms-tasks-tst-" \
  --region ap-southeast-2 \
  --profile <your-profile>
```

Expected output might show multiple log groups:
```
dms-tasks-tst-onedata-projects-serverless-full-cdc
dms-tasks-tst-onedata-exchange-serverless-full-cdc
```

**Note**: The module will discover ALL matching log groups automatically.
### 2. Initialize Terraform

```bash
cd terraform/infrastructure/dms-cw-subscription-filters/environments/digitalnp/tst
terragrunt init
```

### 3. Review the Plan

```bash
terragrunt plan
```

Expected changes:
```
Terraform will perform the following actions:

  # aws_cloudwatch_log_subscription_filter.dms_task_logs will be created
  + resource "aws_cloudwatch_log_subscription_filter" "dms_task_logs" {
      + destination_arn = "arn:aws:firehose:ap-southeast-2:570723136177:deliverystream/tst-onedata-projects-firehose-delivery-stream"
      + filter_pattern  = ""
      + log_group_name  = "dms-tasks-tst-onedata-projects-serverless-full-cdc"
      + name            = "tst-onedata-projects-dms-to-splunk"
      + role_arn        = "arn:aws:iam::570723136177:role/tst-onedata-projects-CWLogsSubFilterIAMRole"
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

### 4. Apply the Configuration

```bash
terragrunt apply
```

Type `yes` when prompted.

### 5. Verify Subscription Filters

Check what was created:

```bash
# See discovered log groups
terragrunt output log_groups_discovered

# See filtered log groups (with subscription filters)
terragrunt output log_groups_monitored

# See subscription filter names
terragrunt output subscription_filter_names

# Verify in AWS for a specific log group
aws logs describe-subscription-filters \
  --log-group-name dms-tasks-tst-onedata-projects-serverless-full-cdc \
  --region ap-southeast-2
```

Expected output shows subscription filters for ALL matching DMS log groups.
### 6. Test Log Forwarding

Trigger some DMS activity and verify logs appear in Splunk. Coordinate with the Splunk team to confirm logs are being received.

## Deploying to Other Environments

### DEV Environment

1. Create directory: `terraform/infrastructure/dms-cw-subscription-filters/environments/digitalnp/dev/`
2. Create `terragrunt.hcl` with DEV-specific values
3. Get Firehose ARN and IAM role ARN from Splunk team for DEV account
4. Follow steps 2-6 above

### PST/PRD Environments

Same process as DEV, but:
- Use appropriate account numbers
- Get production Firehose/IAM role ARNs from Splunk team
- Consider adding manual approval in CI/CD workflow

## Troubleshooting

### Error: "Log group does not exist"

**Cause**: DMS replication task hasn't created the log group yet.

**Solution**: 
1. Verify DMS task is running
2. Check CloudFormation stack has `EnableLogging: "true"`
3. Wait for DMS to create the log group (happens on first run)

### No log groups discovered

**Cause**: Prefix or pattern doesn't match any log groups.

**Solution**:
1. Check `dms_task_ids` in terragrunt.hcl
2. List log groups: `aws logs describe-log-groups --log-group-name-prefix "dms-tasks-"`
3. Adjust prefix or pattern to match actual log group names
4. Set `log_group_pattern = ""` to disable filtering

### Too many log groups discovered

**Cause**: Prefix is too broad, catching unwanted log groups.

**Solution**:
1. Make prefix more specific: `dms-tasks-tst-` instead of `dms-tasks-`
2. Add regex pattern: `log_group_pattern = ".*onedata.*"`
3. Run `terragrunt plan` to preview what will be created

### Error: "Access Denied" when creating subscription filter

**Cause**: IAM role doesn't have permission to assume the subscription filter role.

**Solution**: Contact Splunk team to verify the IAM role trust policy allows CloudWatch Logs service.

### Logs not appearing in Splunk

**Cause**: Multiple possible issues.

**Solution**:
1. Verify subscription filter exists (step 5)
2. Check Firehose delivery stream is active
3. Verify IAM role has `firehose:PutRecord` permissions
4. Contact Splunk team to check their ingestion pipeline

## Rollback

To remove the subscription filter:

```bash
cd terraform/infrastructure/dms-cw-subscription-filters/environments/digitalnp/tst
terragrunt destroy
```

This will NOT affect the DMS replication task or CloudFormation stack.

## Impact Assessment

✅ **Safe to deploy**:
- Does not modify existing CloudFormation DMS stack
- Does not affect DMS replication task operation
- Only creates a subscription filter resource
- Can be removed without impacting DMS

❌ **No impact on**:
- DMS endpoints
- DMS replication configuration
- S3 target buckets
- Database connections
