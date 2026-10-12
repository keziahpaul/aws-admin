output "runtime_arn" {
  description = "ARN of the AgentCore runtime"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
}

output "runtime_id" {
  description = "ID of the AgentCore runtime"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
}

output "runtime_endpoint_arn" {
  description = "ARN of the AgentCore runtime endpoint"
  value       = aws_bedrockagentcore_agent_runtime_endpoint.this.agent_runtime_endpoint_arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the runtime container image"
  value       = aws_ecr_repository.runtime.repository_url
}

output "security_group_id" {
  description = "ID of the security group attached to the AgentCore runtime"
  value       = aws_security_group.this.id
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for the runtime"
  value       = aws_cloudwatch_log_group.runtime.arn
}
