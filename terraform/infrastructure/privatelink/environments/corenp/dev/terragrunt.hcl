include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../.."
}

remote_state {
  backend = "s3"
  config = {
    bucket               = "remote-tfstate-ap-southeast-2-526552200036"
    key                  = "infrastructure/privatelink/corenp/dev/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "fivetran"
    
    # Skip S3 security checks for shared bucket
    skip_bucket_versioning              = true
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_root_access            = true
  }
}

inputs = {
  environment                 = "dev"
  vpc_id                      = "vpc-a10bc2c5"
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
  custom_security_group_id    = ["sg-03a19c8aa5637d989"]
  allowed_principals          = ["arn:aws:iam::024848462836:root"]
}
