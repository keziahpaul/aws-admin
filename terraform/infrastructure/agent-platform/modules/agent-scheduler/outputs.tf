output "schedule_arn" {
  description = "ARN of the EventBridge schedule"
  value       = aws_scheduler_schedule.this.arn
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function that proxies invocations to the AgentCore runtime"
  value       = aws_lambda_function.trigger.arn
}
