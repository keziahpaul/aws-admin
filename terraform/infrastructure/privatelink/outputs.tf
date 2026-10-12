output "vpc_endpoint_service_id" {
  description = "The ID of the VPC Endpoint Service"
  value       = module.snowflake_rds_privatelink.endpoint_service_id
}

output "vpc_endpoint_service_name" {
  description = "The name of the VPC Endpoint Service"
  value       = "com.amazonaws.vpce.${var.aws_region}.${module.snowflake_rds_privatelink.endpoint_service_id}"
}

output "network_load_balancer_id" {
  description = "The ID of the Network Load Balancer"
  value       = module.snowflake_rds_privatelink.network_load_balancer_id
}

output "network_load_balancer_arn" {
  description = "The ARN of the Network Load Balancer"
  value       = module.snowflake_rds_privatelink.network_load_balancer_arn
}

output "security_group_id" {
  description = "The ID of the Security Group"
  value       = module.snowflake_rds_privatelink.security_group_id
}