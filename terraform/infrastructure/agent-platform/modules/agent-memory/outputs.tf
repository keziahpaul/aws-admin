output "memory_id" {
  description = "ID of the AgentCore memory store"
  value       = aws_bedrockagentcore_memory.this.id
}

output "memory_arn" {
  description = "ARN of the AgentCore memory store"
  value       = aws_bedrockagentcore_memory.this.arn
}

output "memory_strategy_id" {
  description = "ID of the first memory strategy"
  value       = length(aws_bedrockagentcore_memory_strategy.this) > 0 ? values(aws_bedrockagentcore_memory_strategy.this)[0].memory_strategy_id : ""
}
