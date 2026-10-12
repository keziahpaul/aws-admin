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
    key                  = "infrastructure/rds-dns-resolver/digitalnp/pst/terraform.tfstate"
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
  environment         = "pst"
  project             = "snowflake"
  cost_centre         = "one-data"
  capability          = "rds-dns-resolver"
  log_retention_days  = 30
  retain_lambda_logs  = true
  
  # RDS-NLB Mappings - Add/modify as needed
  rds_nlb_mappings = {
    # Example configuration - replace with your actual values
    "pstsotmsapiinvitatio-db" = {
      db_identifier    = "pstsotmsapiinvitatio"
      private_link_nlb = "pst-snowflake-privatelink-nlb"
      port            = 5432
      description     = "Snowflake NLB connection for pstsotmsapiinvitatio DB "
    }

    "pstgapinotifications-db" = {
      db_identifier    = "pstgapinotifications"
      private_link_nlb = "pst-snowflake-privatelink-nlb"
      port            = 5432
      description     = "Snowflake NLB connection for pstgapinotifications DB "
    }
    
    # Add more RDS-NLB pairs as needed
    # "secondary-db" = {
    #   db_identifier    = "my-secondary-rds-instance"
    #   private_link_nlb = "secondary-nlb-name"
    #   port            = 5432
    #   description     = "Secondary database"
    # }
  }
}
