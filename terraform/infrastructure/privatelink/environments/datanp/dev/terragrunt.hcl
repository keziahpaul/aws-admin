include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../.."
}

remote_state {
  backend = "s3"
  config = {
    bucket               = "remote-tfstate-ap-southeast-2-042775015153"
    key                  = "infrastructure/privatelink/digitalnp/dev/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "onedata"
    
    # Skip S3 security checks for shared bucket
    skip_bucket_versioning             = true
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_root_access            = true
  }
}

inputs = {
  environment                 = "dev"
  vpc_id                      = "vpc-67e19503"
  project                     = "snowflake"
  cost_centre                 = "one-data"
  nlb_tg_port                 = 5432
  nlb_access_logs_enabled     = false
  nlb_tg_protocol             = "TCP"
  ingress_from_port           = 5432
  ingress_to_port             = 5432
  ingress_cidr_block          = ["10.0.0.0/8"]
  ingress_protocol_type       = "tcp"
  custom_egress_from_port     = 5432
  custom_egress_to_port       = 5432
  custom_egress_protocol_type = "tcp"
  custom_security_group_id    = ["sg-0c6f1a31b7e125693"]
  allowed_principals          = ["arn:aws:iam::024848462836:root"]
}
