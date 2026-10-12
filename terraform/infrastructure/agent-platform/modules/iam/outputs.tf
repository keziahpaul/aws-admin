output "task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  value       = aws_iam_role.task_execution.arn
}

output "task_execution_role_name" {
  description = "Name of the ECS task execution IAM role"
  value       = aws_iam_role.task_execution.name
}

output "task_role_arn" {
  description = "ARN of the ECS task IAM role"
  value       = aws_iam_role.task_role.arn
}

output "task_role_name" {
  description = "Name of the ECS task IAM role"
  value       = aws_iam_role.task_role.name
}

output "bedrock_kb_role_arn" {
  description = "ARN of the Bedrock KB service IAM role (empty string when no KB bucket is provided)"
  value       = var.kb_bucket_arn != "" ? aws_iam_role.bedrock_kb[0].arn : ""
}

output "bedrock_kb_role_name" {
  description = "Name of the Bedrock KB service IAM role (empty string when no KB bucket is provided)"
  value       = var.kb_bucket_arn != "" ? aws_iam_role.bedrock_kb[0].name : ""
}

output "agentcore_runtime_role_arn" {
  description = "ARN of the AgentCore runtime IAM role"
  value       = aws_iam_role.agentcore_runtime.arn
}
