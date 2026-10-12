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
    key                  = "infrastructure/rds-dns-resolver/digitalprd/prd/terraform.tfstate"
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
  environment         = "prd"
  project             = "snowflake"
  cost_centre         = "one-data"
  capability          = "rds-dns-resolver"
  log_retention_days  = 90  # Longer retention for production
  retain_lambda_logs  = true
  
  # RDS-NLB Mappings - Add/modify as needed
  rds_nlb_mappings = {
    "prdsotmsapiinvitatio-db" = {
      db_identifier     = "prdsotmsapiinvitatio"
      private_link_nlb  = "prd-snowflake-privatelink-nlb"
      port              = 5432
      description       = "Snowflake NLB connection for prdsotmsapiinvitatio DB "
    }

    "prdgapinotifications-db" = {
      db_identifier     = "prdgapinotifications"
      private_link_nlb  = "prd-snowflake-privatelink-nlb"
      port              = 5432
      description       = "Snowflake NLB connection for prdgapinotifications DB "
    }
  }
}
