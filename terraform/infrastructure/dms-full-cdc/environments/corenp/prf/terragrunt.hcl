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
    key                  = "onedata/infrastructure/onedata-exchange-resources-core-DMS-full-cdc/corenp/prf/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "onedata"
    
    skip_bucket_versioning              = true
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_root_access            = true
  }
}

inputs = {
  environment        = "prf02"
  account           = "526552200036"
  onedata_account   = "042775015153"
  min_dcu          = 1
  max_dcu          = 8
  dms_subnet_group = "default-vpc-4c0ac328"
  security_group_id = "sg-0dcfe8c7bf937ab24"
  
  # Common tags
  project     = "onedata-exchange"
  cost_centre = "onedata"
  aws_region  = "ap-southeast-2"
}