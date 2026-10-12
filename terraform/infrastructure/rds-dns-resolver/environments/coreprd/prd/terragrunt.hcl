include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../.."
}

remote_state {
  backend = "s3"
  config = {
    bucket               = "remote-tfstate-ap-southeast-2-215597176832"
    key                  = "infrastructure/rds-dns-resolver/coreprd/prd/terraform.tfstate"
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
  environment       = "prd"
  project          = "snowflake"
  cost_centre      = "one-data"
  capability       = "rds-dns-resolver"
  db_identifier    = "REPLACE_WITH_YOUR_RDS_INSTANCE_NAME"
  private_link_nlb = "REPLACE_WITH_YOUR_NLB_NAME"
  log_retention_days = 90  # Longer retention for production
  retain_lambda_logs = true
}
