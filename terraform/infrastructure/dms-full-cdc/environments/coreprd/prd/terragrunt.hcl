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
    key                  = "onedata/infrastructure/onedata-exchange-resources-core-DMS-full-cdc/coreprd/prd/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "onedata"
    
    skip_bucket_versioning              = true
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_root_access            = true
  }
}

inputs = {
  environment       = "prd"
  account           = "215597176832"
  onedata_account   = "725563543552"
  min_dcu           = 1
  max_dcu           = 8
  dms_subnet_group  = "onedata-exchange-dms-subnet-group"
  security_group_id = "sg-0caed91dcc5b3a677"
  
  # PRD-specific DMS settings
  preferred_maintenance_window = "sun:13:00-sun:15:00"
  max_full_load_sub_tasks      = 16
  
  # Common tags
  project     = "onedata-exchange"
  cost_centre = "onedata"
  aws_region  = "ap-southeast-2"
}