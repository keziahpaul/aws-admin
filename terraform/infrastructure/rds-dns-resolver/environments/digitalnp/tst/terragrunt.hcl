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
    key                  = "infrastructure/rds-dns-resolver/digitalnp/tst/terraform.tfstate"
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
  environment         = "tst"
  project             = "snowflake"
  cost_centre         = "one-data"
  capability          = "rds-dns-resolver"
  log_retention_days  = 30
  retain_lambda_logs  = true
  
  # RDS-NLB Mappings
  rds_nlb_mappings = {
    "tstsotmsapiinvitatio-db" = {
      db_identifier    = "tstsotmsapiinvitatio"
      private_link_nlb = "tst-snowflake-privatelink-nlb"
      port            = 5432
      description     = "Snowflake NLB connection for tstsotmsapiinvitatio DB "
    }

    "tstgapinotifications-db" = {
      db_identifier    = "tstgapinotifications"
      private_link_nlb = "tst-snowflake-privatelink-nlb"
      port            = 5432
      description     = "Snowflake NLB connection for tstgapinotifications DB "
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
