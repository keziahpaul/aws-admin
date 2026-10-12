output "dms_task_arn" {
  description = "DMS Serverless full-cdc Onedata-Exchange ARN"
  value       = aws_dms_replication_config.onedata_exchange_full_cdc.arn
}
