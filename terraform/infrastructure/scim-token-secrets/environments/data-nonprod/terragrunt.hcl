include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../.."
}

remote_state {
  backend = "s3"
  config = {
    bucket               = "pexa-one-data-tfstate-042775015153"
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
  environment        = "non-prod"
  env_type           = "nonprod"
  snowflake_accounts = ["exchange", "group", "landinsights", "value-australia","px","aml"]

  rotator_role_arn = "arn:aws:iam::042775015153:role/GitHubRunnerPEXAOneDataRole"
  okta_role_arn    = "arn:aws:iam::042775015153:role/aws-reserved/sso.amazonaws.com/ap-southeast-2/AWSReservedSSO_PexaSOCAccess_49a4e874f452f7af"
}
