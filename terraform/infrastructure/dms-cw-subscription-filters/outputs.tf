output "subscription_filter_names" {
  description = "Names of all DMS CloudWatch Logs subscription filters created"
  value       = { for k, v in aws_cloudwatch_log_subscription_filter.dms_task_logs : k => v.name }
}

output "log_groups_monitored" {
  description = "CloudWatch Log Groups being monitored"
  value       = local.filtered_log_groups
}

output "log_groups_discovered" {
  description = "All DMS log groups discovered (before filtering)"
  value       = local.all_log_groups
}

output "subscription_filter_count" {
  description = "Number of subscription filters created"
  value       = length(local.filtered_log_groups)
}
