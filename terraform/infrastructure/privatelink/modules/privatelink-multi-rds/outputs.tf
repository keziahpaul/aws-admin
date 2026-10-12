output "network_load_balancer_id" {
  value = aws_lb.nlb.id
}

output "network_load_balancer_arn" {
  value = aws_lb.nlb.arn
}

output "security_group_id" {
  value = aws_security_group.security_group.id
}

output "endpoint_service_id" {
  value = aws_vpc_endpoint_service.nlb_vpce_service.id
}

output "target_group_arns" {
  value = { for k, v in aws_lb_target_group.rds : k => v.arn }
}

output "listener_ports" {
  value = { for k, v in aws_lb_listener.rds : k => v.port }
}
