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
    key                  = "infrastructure/dms-cw-subscription-filters/digitalprd/prd/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "onedata"
    
    skip_bucket_versioning              = true
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_root_access            = true
  }
}

inputs = {
  environment                      = "prd"
  dms_task_ids                     = ["PZ74ZXGMS5FIPNGOEAOWJGVPXA"]
  log_group_pattern                = ""
  firehose_delivery_stream_arn     = "arn:aws:firehose:ap-southeast-2:597924334156:deliverystream/prd-onedata-projects-firehose-delivery-stream"  
  subscription_filter_role_arn     = "arn:aws:iam::597924334156:role/prd-onedata-projects-CWLogsSubFilterIAMRole"
}
