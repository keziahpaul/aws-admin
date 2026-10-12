include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${find_in_parent_folders("infrastructure")}//lambda"
}

remote_state {
  backend = "s3"
  config = {
    bucket = "pexa-one-data-tfstate-042775015153"
    key    = "infrastructure/lambda/datanp/tst/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

inputs = {
  environment = "tst"
  env_type    = "non-prod"
  project     = "one-data"
  cost_centre = "one-data"
  
  lambda_function_name = "onedata-ingestion-validation-tst"
  lambda_runtime       = "python3.12"
  lambda_handler       = "lambda_function.lambda_handler"
  lambda_timeout       = 300
  lambda_memory_size   = 512
  
  source_path        = "${dirname(find_in_parent_folders())}/../lambda/data-ingestion-validation"
  source_bucket_name = "onedata-px-ingest-${get_aws_account_id()}-tst"
  target_bucket_name = "onedata-ingress-${get_aws_account_id()}-tst"
  
  data_sources = {
    empower = {
      enabled = true
      uploaded_prefixes = [
        "empower/uploaded/future_leave",
        "empower/uploaded/fy_leave_taken",
        "empower/uploaded/leave_provision",
        "empower/uploaded/leave_taken_last_month"
      ]
      config_prefixes = [
        "empower/config/future_leave",
        "empower/config/fy_leave_taken",
        "empower/config/leave_provision",
        "empower/config/leave_taken_last_month"
      ]
      verified_prefixes = [
        "empower/verified/future_leave",
        "empower/verified/fy_leave_taken",
        "empower/verified/leave_provision",
        "empower/verified/leave_taken_last_month"
      ]
    }
    hibob = {
      enabled           = false
      uploaded_prefixes  = []
      config_prefixes    = []
      verified_prefixes  = []
    }
    lever = {
      enabled           = false
      uploaded_prefixes  = []
      config_prefixes    = []
      verified_prefixes  = []
    }
  }
  
  slack_webhook_secret = "onedata-slack-app-bot-token"
}
