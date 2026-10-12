include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../.."
}

remote_state {
  backend = "s3"
  config = {
    bucket               = "remote-tfstate-ap-southeast-2-dataprd"
    key                  = "infrastructure/agent-platform/dataprd/pst/terraform.tfstate"
    region               = "ap-southeast-2"
    workspace_key_prefix = "onedata"

    # Skip S3 security checks for shared bucket
    skip_bucket_versioning             = true
    skip_bucket_ssencryption           = true
    skip_bucket_public_access_blocking = true
    skip_bucket_root_access            = true
  }
}

locals {
  common = read_terragrunt_config("${get_terragrunt_dir()}/common.hcl")

  # Auto-discover all agent HCL files in agents/ directory
  agent_files = fileset("${get_terragrunt_dir()}/agents", "*.hcl")
  agents = [
    for f in local.agent_files :
    read_terragrunt_config("${get_terragrunt_dir()}/agents/${f}").locals.agent
  ]
}

inputs = {
  # Common settings
  environment                  = local.common.locals.environment
  vpc_id                       = local.common.locals.vpc_id
  private_subnet_ids           = local.common.locals.private_subnet_ids
  use_fargate_spot             = local.common.locals.use_fargate_spot
  create_opensearch_collection = local.common.locals.create_opensearch_collection

  # Project metadata
  project     = "snowflake"
  cost_centre = "one-data"

  # Auto-discovered agents
  agents = local.agents
}
