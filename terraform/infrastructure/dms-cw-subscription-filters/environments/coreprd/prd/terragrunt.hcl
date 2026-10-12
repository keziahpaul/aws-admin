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
    key                  = "infrastructure/dms-cw-subscription-filters/coreprd/prd/terraform.tfstate"
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
  dms_task_ids                     = ["25UPVZP3GVEY5LHE5VJU3NSCHE"]
  log_group_pattern                = ""
  firehose_delivery_stream_arn     = "arn:aws:firehose:ap-southeast-2:215597176832:deliverystream/prd-onedata-dms-firehose-delivery-stream"
  subscription_filter_role_arn     = "arn:aws:iam::215597176832:role/prd-onedata-dms-CWLogsSubFilterIAMRole"
}
