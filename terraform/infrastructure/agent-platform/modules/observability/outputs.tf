output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarm notifications"
  value       = aws_sns_topic.alarms.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}

output "alarm_arns" {
  description = "Map of alarm name to ARN for all created CloudWatch alarms"
  value = {
    error_rate        = aws_cloudwatch_metric_alarm.error_rate.arn
    latency_p99       = aws_cloudwatch_metric_alarm.latency_p99.arn
    ecs_running_tasks = aws_cloudwatch_metric_alarm.ecs_running_tasks.arn
  }
}
