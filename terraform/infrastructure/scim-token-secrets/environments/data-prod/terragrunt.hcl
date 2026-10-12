include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../.."
}

remote_state {
  backend = "s3"
  config = {
    bucket               = "pexa-one-data-tfstate-725563543552"
    key                  = "infrastructure/scim-token-secrets/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "onedata"

    skip_bucket_versioning              = true
    skip_bucket_ssencryption            = true
    skip_bucket_public_access_blocking  = true
    skip_bucket_root_access             = true
  }
}

inputs = {
  environment        = "prod"
  env_type           = "prod"
  snowflake_accounts = ["exchange", "group", "landinsights", "value-australia","px","aml"]

  rotator_role_arn = "arn:aws:iam::725563543552:role/GitHubRunnerPEXAOneDataRole"
  okta_role_arn    = "arn:aws:iam::725563543552:role/aws-reserved/sso.amazonaws.com/ap-southeast-2/AWSReservedSSO_PexaSOCAccess_e3ac2e4902b29279"
}
