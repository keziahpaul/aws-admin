output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.slack_bot.name
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.slack_bot.id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the Slack bot image (empty when create_ecr_repository = false)"
  value       = var.create_ecr_repository ? aws_ecr_repository.slack_bot[0].repository_url : var.slack_bot_image
}

output "security_group_id" {
  description = "ID of the security group attached to ECS tasks"
  value       = aws_security_group.slack_bot.id
}
