include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../.."
}

remote_state {
  backend = "s3"
  config = {
    bucket               = "remote-tfstate-ap-southeast-2-597924334156"
    key                  = "infrastructure/privatelink/digitalprd/terraform.tfstate"
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
  environment                 = "prd"
  vpc_id                      = "vpc-dd18f5b9"
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
  custom_security_group_id    = ["sg-0f8e1878bde71bf07","sg-0ec51d1f277a96577"]
  allowed_principals          = ["arn:aws:iam::024848462836:root"]
  
  # All RDS target groups in single map
  target_groups = {
    "sotmsapi" = {  # Primary RDS (existing)
      target_port   = 5432
      listener_port = 5432
      description   = "prdsotmsapiinvitatio RDS"
    }
    "gapinotif" = {  # Additional RDS
      target_port   = 5432
      listener_port = 5433
      description   = "prdgapinotifications RDS"
    }
    # Add more as needed:
    # "sotmsapi" = {
    #   target_port   = 5432
    #   listener_port = 5434
    #   description   = "Another RDS"
    # }
  }
}
