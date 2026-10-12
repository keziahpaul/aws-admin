include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../.."
}

remote_state {
  backend = "s3"
  config = {
    bucket               = "remote-tfstate-ap-southeast-2-570723136177"
    key                  = "infrastructure/privatelink/digitalnp/pst/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "onedata"
    
    # Skip S3 security checks for shared bucket
    skip_bucket_versioning              = true
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_root_access            = true
  }
}

inputs = {
  environment                 = "pst"
  vpc_id                      = "vpc-1199a074"
  project                     = "snowflake"
  cost_centre                 = "one-data"
  nlb_access_logs_enabled     = false
  ingress_from_port           = 5432
  ingress_to_port             = 5440
  ingress_cidr_block          = ["10.0.0.0/8"]
  ingress_protocol_type       = "tcp"
  custom_egress_from_port     = 5432
  custom_egress_to_port       = 5432
  custom_egress_protocol_type = "tcp"
  custom_security_group_id    = ["sg-0a0df747393b78dfb", "sg-0e73ed8f73ae7c9f5"]
  allowed_principals          = ["arn:aws:iam::024848462836:root"]
  
  # All RDS target groups in single map
  target_groups = {
    "sotmsapi" = {  # Primary RDS (existing)
      target_port   = 5432
      listener_port = 5432
      description   = "pstsotmsapiinvitatio RDS"
    }
    "gapinotif" = {  # Additional RDS
      target_port   = 5432
      listener_port = 5433
      description   = "pstgapinotifications RDS"
    }
    # Add more as needed:
    # "sotmsapi" = {
    #   target_port   = 5432
    #   listener_port = 5434
    #   description   = "Another RDS"
    # }
  }
}
