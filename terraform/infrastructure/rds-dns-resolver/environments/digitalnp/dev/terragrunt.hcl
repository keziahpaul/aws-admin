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
    key                  = "infrastructure/rds-dns-resolver/digitalnp/dev/terraform.tfstate"
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
  environment         = "dev"
  project             = "snowflake"
  cost_centre         = "one-data"
  capability          = "rds-dns-resolver"
  log_retention_days  = 30
  retain_lambda_logs  = true
  
  # RDS-NLB Mappings
  rds_nlb_mappings = {
    "devsotmsapiinvitatio-db" = {
      db_identifier    = "devsotmsapiinvitatio"
      private_link_nlb = "dev-snowflake-privatelink-nlb"
      port            = 5432
      description     = "Snowflake NLB connection for devsotmsapiinvitatio DB "
    }

    "devgapinotifications-db" = {
      db_identifier    = "devgapinotifications"
      private_link_nlb = "dev-snowflake-privatelink-nlb"
      port            = 5432
      description     = "Snowflake NLB connection for devgapinotifications DB "
    }
    
    # Add more RDS-NLB pairs as needed
    # "analytics-db" = {
    #   db_identifier    = "my-analytics-rds-instance"
    #   private_link_nlb = "analytics-nlb-name"
    #   port            = 5432
    #   description     = "Analytics database"
    # }
    
    # "reporting-db" = {
    #   db_identifier    = "my-reporting-rds-instance"
    #   private_link_nlb = "reporting-nlb-name"
    #   port            = 5432
    #   description     = "Reporting database"
    # }
  }
}
