# SCIM Token Secrets

Terraform module for managing Snowflake SCIM token secrets in AWS Secrets Manager.

## Overview

Creates:
- KMS key for encrypting SCIM token secrets
- Per-account Secrets Manager secrets (`onedata/snowflake/{account}/{nonprod|prod}/scim-token`)
- Resource policies for rotator and Okta cross-account access

## Usage

```bash
cd environments/data-nonprod
terragrunt init
terragrunt plan
terragrunt apply
```

## Inputs

| Name | Description | Required |
|------|-------------|----------|
| `environment` | Environment name (np, prd) | Yes |
| `env_type` | Environment type for SCIM tokens (nonprod or prod) | Yes |
| `snowflake_accounts` | List of Snowflake account names | Yes |
| `rotator_role_arn` | IAM role ARN for the SCIM token rotator | Yes |
| `okta_role_arn` | IAM role ARN for Okta cross-account access | Yes |

## Outputs

| Name | Description |
|------|-------------|
| `kms_key_arn` | ARN of the KMS key |
| `secret_arns` | Map of account name to secret ARN |

## Prerequisites

Before applying:
1. Get the Okta team's IAM role ARN for cross-account access
2. Create/identify the GitHub Actions role ARN for the rotator
3. Update the `terragrunt.hcl` files with actual role ARNs
