# GitHub Workflow Usage Guide

## Overview

The DMS CloudWatch Subscription Filters deployment uses GitHub Actions workflows similar to the existing PrivateLink and RDS DNS Resolver patterns.

## Workflow Files

1. **Main Workflow**: `.github/workflows/deploy-dms-cw-subscription-filters.yml`
   - Validates configuration
   - Determines AWS account and environment
   - Calls reusable workflow

2. **Reusable Workflow**: `.github/workflows/reusable-dms-cw-subscription-filters.yml`
   - Executes Terragrunt commands
   - Handles branch permissions
   - Manages deployment lifecycle

3. **Configuration**: `.github/config/dms-cw-subscription-filters-accounts.json`
   - Maps accounts to environments
   - Defines Terragrunt paths
   - Specifies IAM roles

## How to Deploy

### Via GitHub UI (Manual Trigger)

1. Go to **Actions** tab in GitHub
2. Select **Deploy DMS CloudWatch Subscription Filters**
3. Click **Run workflow**
4. Select:
   - **AWS Account**: `digitalnp` or `digitalprd`
   - **Environment**: `dev`, `tst`, `pst`, or `prd`
   - **Dry Run**: Check for plan-only (no apply)
5. Click **Run workflow**

### Branch Permissions

| Environment | Allowed Branches |
|-------------|------------------|
| dev | `feature/*` |
| tst | `develop` |
| pst | `develop`, `main`, `release/*` |
| prd | `develop`, `main`, `release/*` |

### Workflow Steps

1. **Validate Configuration**
   - Loads account config from JSON
   - Validates environment for account
   - Constructs Terragrunt path

2. **Terragrunt Init**
   - Initializes Terraform backend
   - Downloads providers

3. **Terragrunt Validate**
   - Validates Terraform syntax

4. **Terragrunt Plan**
   - Shows what will change
   - Exit codes:
     - `0`: No changes
     - `1`: Error
     - `2`: Changes detected

5. **Branch Permission Check**
   - Validates branch is allowed for environment
   - Only runs if changes detected

6. **Terragrunt Apply** (if not dry-run)
   - Applies changes
   - Auto-approves (no manual confirmation)

7. **Show Outputs**
   - Displays Terraform outputs

## IAM Role Required

The workflow uses the existing IAM role:
```
arn:aws:iam::{account-id}:role/GitHubRunnerPEXAOneDataRole
```

This is the same role used by the DMS full CDC CloudFormation workflows.

### Required Additional Permissions

The existing role needs these additional permissions for subscription filters:
- `logs:PutSubscriptionFilter`
- `logs:DescribeSubscriptionFilters`
- `logs:DeleteSubscriptionFilter`
- `iam:PassRole` (for the subscription filter role provided by Splunk team)

### Permissions Policy to Add

Add this policy to the existing `GitHubRunnerPEXAOneDataRole`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchLogsSubscriptionFilters",
      "Effect": "Allow",
      "Action": [
        "logs:PutSubscriptionFilter",
        "logs:DescribeSubscriptionFilters",
        "logs:DeleteSubscriptionFilter",
        "logs:DescribeLogGroups"
      ],
      "Resource": "arn:aws:logs:ap-southeast-2:{account-id}:log-group:dms-tasks-*"
    },
    {
      "Sid": "PassRoleToSubscriptionFilter",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::{account-id}:role/*-CWLogsSubFilterIAMRole"
    }
  ]
}
```

**Note**: The role likely already has S3 permissions for Terraform state since it's used for other deployments.

## Dry Run Mode

To test without making changes:
1. Check **Do NOT Execute (dry run mode)**
2. Workflow will run `terragrunt plan` only
3. No resources will be created/modified

## Troubleshooting

### "Configuration file not found"
- Ensure `.github/config/dms-cw-subscription-filters-accounts.json` exists
- Check file is committed to repository

### "Invalid AWS account"
- Verify account name matches config file
- Available: `digitalnp`, `digitalprd`

### "Terragrunt path not found"
- Ensure environment folder exists
- Check `terraform/infrastructure/dms-cw-subscription-filters/environments/{account}/{env}/`

### "Access Denied" during deployment
- Verify `GitHubRunnerPEXAOneDataRole` has subscription filter permissions
- Check role can PassRole to the Splunk-provided IAM role
- Confirm role has access to Terraform state bucket

### "Branch not allowed"
- Check branch permissions table above
- Use correct branch for environment
- Feature branches only work for `dev`

## Example: Deploy to TST

```bash
# Via GitHub UI:
# 1. Actions → Deploy DMS CloudWatch Subscription Filters
# 2. Run workflow
# 3. Select:
#    - AWS Account: digitalnp
#    - Environment: tst
#    - Dry Run: false (unchecked)
# 4. Ensure you're on 'develop' branch
# 5. Run workflow
```

## Monitoring Deployment

1. Click on the running workflow
2. Expand job steps to see progress
3. Check **Summary** tab for deployment info
4. Review Terragrunt outputs at the end
