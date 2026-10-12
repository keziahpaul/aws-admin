# Root Terragrunt Configuration
# This file contains common configuration for all infrastructure deployments

locals {
  # Common variables across all services
  common_vars = {
    aws_region = "ap-southeast-2"
  }
}

# Generate provider configuration
generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
      CostCentre  = var.cost_centre
      ManagedBy   = "terragrunt"
      Team        = "onedata-snowflake"
    }
  }
}
EOF
}

# Common inputs for all environments
inputs = local.common_vars
