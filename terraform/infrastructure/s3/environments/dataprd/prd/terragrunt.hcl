include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${find_in_parent_folders("infrastructure")}//s3"
}

locals {
  environment = "prd"
}

remote_state {
  backend = "s3"
  config = {
    bucket               = "pexa-one-data-tfstate-725563543552"
    key                  = "infrastructure/s3/dataprd/prd/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "onedata"
    
    skip_bucket_versioning             = true
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_root_access            = true
  }
}

inputs = {
  bucket_name = "onedata-px-ingest-${get_aws_account_id()}-${local.environment}"
  environment = local.environment
  env_type    = "prod"
  project     = "one-data"
  cost_centre = "one-data"
  
  # TODO: Update with prod SSO role ARN
  business_user_role_arns = [
    "arn:aws:iam::${get_aws_account_id()}:role/aws-reserved/sso.amazonaws.com/ap-southeast-2/AWSReservedSSO_OnedataPXUsers_*"
  ]

  business_user_role_arns = []

  data_sources = {
    empower = {
      enabled = true
      uploaded_prefixes = [
        "empower/uploaded/future_leave",
        "empower/uploaded/fy_leave_taken",
        "empower/uploaded/leave_provision",
        "empower/uploaded/leave_taken_last_month"
      ]
    }
    hibob = {
      enabled           = false
      uploaded_prefixes  = []
    }
    lever = {
      enabled           = false
      uploaded_prefixes  = []
    }
  }
}
