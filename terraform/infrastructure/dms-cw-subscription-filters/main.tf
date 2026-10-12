terraform {
  backend "s3" {}
}

locals {
  # Generate log group names from DMS task IDs
  dms_log_groups = [
    for id in var.dms_task_ids : "dms-serverless-replication-${id}"
  ]

  # Filter by pattern if provided
  filtered_log_groups = var.log_group_pattern != "" ? [
    for lg in local.dms_log_groups : lg
    if can(regex(var.log_group_pattern, lg))
  ] : local.dms_log_groups
  all_log_groups = local.dms_log_groups
}

# Create subscription filter for each DMS log group
resource "aws_cloudwatch_log_subscription_filter" "dms_task_logs" {
  for_each = toset(local.filtered_log_groups)

  name            = "${var.environment}-${each.value}-to-splunk"
  log_group_name  = each.value
  filter_pattern  = ""
  destination_arn = var.firehose_delivery_stream_arn
  role_arn        = var.subscription_filter_role_arn
}

