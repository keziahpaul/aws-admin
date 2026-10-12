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
    key                  = "infrastructure/dms-cw-subscription-filters/digitalnp/tst/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "onedata"
    
    skip_bucket_versioning              = true
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_root_access            = true
  }
}

inputs = {
  environment                      = "tst"
  dms_task_ids                     = ["WHVFP5XJKJFKTHVUQN5A3VKN6Y"]
  log_group_pattern                = ""
  firehose_delivery_stream_arn     = "arn:aws:firehose:ap-southeast-2:570723136177:deliverystream/tst-onedata-projects-firehose-delivery-stream"
  subscription_filter_role_arn     = "arn:aws:iam::570723136177:role/tst-onedata-projects-CWLogsSubFilterIAMRole"
}
