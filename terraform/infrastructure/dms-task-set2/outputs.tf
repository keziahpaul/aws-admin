output "dms_task_arn" {
  description = "DMS Replication Task ARN"
  value       = aws_dms_replication_config.onedata_exchange_dms_task.arn
}