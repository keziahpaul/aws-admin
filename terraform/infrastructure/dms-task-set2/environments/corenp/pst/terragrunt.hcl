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
    key                  = "onedata/infrastructure/dms-task-set2/corenp/pst/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "onedata"
    
    skip_bucket_versioning              = true
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_root_access            = true
  }
}

inputs = {
  environment       = "pst"
  account           = "526552200036"
  onedata_account   = "725563543552"
  min_dcu           = 1
  max_dcu           = 2
  dms_subnet_group  = "default-vpc-7e0ac31a"
  security_group_id = "sg-0b0e92d114b7fc663"
}
