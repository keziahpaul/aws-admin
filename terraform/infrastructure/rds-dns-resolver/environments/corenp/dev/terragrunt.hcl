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
    key                  = "infrastructure/rds-dns-resolver/corenp/dev/terraform.tfstate"
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
  environment        = "dev"
  project           = "snowflake"
  cost_centre       = "one-data"
  capability        = "rds-dns-resolver"
  log_retention_days = 30
  retain_lambda_logs = true
  
  # RDS-NLB Mappings - Add/modify as needed
  rds_nlb_mappings = {
    # Example configuration - replace with your actual values
    "primary-db" = {
      db_identifier    = "REPLACE_WITH_PRIMARY_RDS_INSTANCE_NAME"
      private_link_nlb = "REPLACE_WITH_PRIMARY_NLB_NAME"
      port            = 5432
      description     = "Primary Snowflake database"
    }
  }
}
