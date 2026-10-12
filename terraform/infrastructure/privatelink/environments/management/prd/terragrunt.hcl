include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../.."
}

remote_state {
  backend = "s3"
  config = {
    bucket               = "remote-tfstate-ap-southeast-2-004761221582"
    key                  = "infrastructure/privatelink/management/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "alation"
    
    # Skip S3 security checks for shared bucket
    skip_bucket_versioning              = true
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_root_access            = true
  }
}

inputs = {
  environment                 = "prd"
  vpc_id                      = "vpc-6cb18f09"
  project                     = "alation"
  cost_centre                 = "one-data"
  nlb_tg_port                 = 443
  nlb_access_logs_enabled     = false
  nlb_tg_protocol             = "TCP"
  ingress_from_port           = 443
  ingress_to_port             = 443
  ingress_cidr_block          = ["3.27.127.216/29"]
  ingress_protocol_type       = "tcp"
  custom_egress_from_port     = 443
  custom_egress_to_port       = 443
  custom_egress_protocol_type = "tcp"
  custom_security_group_id    = ["sg-0a8d539164d52f602"]
  allowed_principals          = ["arn:aws:iam::697407175519:root"]
}
