# PrivateLink Infrastructure Composition
# This file composes multiple modules to create the complete privatelink solution

terraform {
  backend "s3" {}
}

module "snowflake_rds_privatelink" {
  source = "./modules/privatelink-multi-rds"

  environment                 = var.environment
  vpc_id                      = var.vpc_id
  project                     = var.project
  cost_centre                 = var.cost_centre
  nlb_access_logs_enabled     = var.nlb_access_logs_enabled
  ingress_from_port           = var.ingress_from_port
  ingress_to_port             = var.ingress_to_port
  ingress_cidr_block          = var.ingress_cidr_block
  ingress_protocol_type       = var.ingress_protocol_type
  custom_egress_from_port     = var.custom_egress_from_port
  custom_egress_to_port       = var.custom_egress_to_port
  custom_egress_protocol_type = var.custom_egress_protocol_type
  custom_security_group_id    = var.custom_security_group_id
  allowed_principals          = var.allowed_principals
  target_groups               = var.target_groups
}
