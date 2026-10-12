# Migration Guide: CloudFormation to Terraform/Terragrunt

This document outlines the migration from the CloudFormation-based RDS DNS Resolver to the new Terraform/Terragrunt implementation.

## Overview

The CloudFormation template has been successfully converted to Terraform with Terragrunt for environment management, following the existing patterns in the `pexa-one-data-aws-admin` repository.

## File Structure

```
terraform/infrastructure/rds-dns-resolver/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── lambda_function.py         # Lambda function code
├── deploy.sh                  # Deployment helper script
├── test-payload.json          # Test payload template
├── README.md                  # Documentation
├── MIGRATION.md              # This file
└── environments/             # Environment-specific configurations
    ├── digitalnp/
    │   ├── dev/terragrunt.hcl
    │   └── pst/terragrunt.hcl
    ├── corenp/
    │   └── dev/terragrunt.hcl
    ├── coreprd/
    │   └── prd/terragrunt.hcl
    └── digitalprd/
        └── prd/terragrunt.hcl
```

## Resource Mapping

| CloudFormation Resource | Terraform Resource | Notes |
|-------------------------|-------------------|-------|
| `AWS::IAM::Role` | `aws_iam_role.rds_dns_resolver_lambda_role` | ✅ Equivalent |
| `AWS::IAM::Policy` | `aws_iam_role_policy.rds_dns_resolver_lambda_policy` | ✅ Inline policy |
| `AWS::Lambda::Function` | `aws_lambda_function.rds_dns_resolver_lambda` | ✅ With zip deployment |
| `AWS::Logs::LogGroup` | `aws_cloudwatch_log_group.rds_dns_resolver_lambda_log_group` | ✅ With retention |
| `AWS::Events::Rule` | `aws_cloudwatch_event_rule.eventbridge_trigger_rule` | ✅ EventBridge rule |
| `AWS::Events::Target` | `aws_cloudwatch_event_target.lambda_target` | ✅ Lambda target |
| `AWS::Lambda::Permission` | `aws_lambda_permission.rds_dns_resolver_lambda_permission` | ✅ EventBridge permission |

## Key Improvements

### 1. **Environment Management**
- **Before**: Manual parameter passing in GitHub Actions
- **After**: Environment-specific Terragrunt configurations with proper state isolation

### 2. **Code Organization**
- **Before**: Inline Lambda code in CloudFormation template
- **After**: Separate Python file with proper formatting and comments

### 3. **State Management**
- **Before**: CloudFormation stack state
- **After**: Terraform state in S3 with workspace isolation

### 4. **Deployment Process**
- **Before**: GitHub Actions with CloudFormation deploy action
- **After**: Terragrunt with helper scripts for local and CI/CD deployment

## Migration Steps

### Step 1: Prepare Configuration

1. **Update Terragrunt files** with your actual values:
   ```bash
   # Edit the appropriate environment file
   vim environments/digitalnp/dev/terragrunt.hcl
   
   # Replace placeholders:
   # - REPLACE_WITH_YOUR_RDS_INSTANCE_NAME
   # - REPLACE_WITH_YOUR_NLB_NAME
   ```

### Step 2: Deploy New Infrastructure

1. **Deploy using the helper script**:
   ```bash
   ./deploy.sh digitalnp dev plan    # Review changes
   ./deploy.sh digitalnp dev apply   # Deploy resources
   ```

2. **Or deploy manually**:
   ```bash
   cd environments/digitalnp/dev
   terragrunt init
   terragrunt plan
   terragrunt apply
   ```

### Step 3: Verify Deployment

1. **Check Lambda function**:
   ```bash
   aws lambda get-function --function-name dev-snowflake-rds-dns-resolver-lambda
   ```

2. **Test manually**:
   ```bash
   # Update test-payload.json with your values
   aws lambda invoke \
     --function-name dev-snowflake-rds-dns-resolver-lambda \
     --payload file://test-payload.json \
     response.json
   ```

3. **Check EventBridge rule**:
   ```bash
   aws events describe-rule --name dev-snowflake-rds-dns-resolver-lambda-trigger-rule
   ```

### Step 4: Remove Old CloudFormation Stack

⚠️ **Only after verifying the new infrastructure works correctly**

1. **Delete the CloudFormation stack**:
   ```bash
   aws cloudformation delete-stack --stack-name dev-snowflake-rds-dns-resolver
   ```

2. **Or use the existing GitHub Actions delete workflow**

## Configuration Differences

### CloudFormation Parameters vs Terragrunt Inputs

| CloudFormation Parameter | Terragrunt Input | Notes |
|--------------------------|------------------|-------|
| `Environment` | `environment` | ✅ Same |
| `Capability` | `capability` | ✅ Same (default: "rds-dns-resolver") |
| `DBIdentifier` | `db_identifier` | ✅ Same |
| `Region` | `aws_region` | ✅ From root config |
| `PrivateLinkNLB` | `private_link_nlb` | ✅ Same |
| `RetainLambdaLogs` | `retain_lambda_logs` | ✅ Boolean instead of string |

### New Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project` | Project name for resource naming | - |
| `cost_centre` | Cost centre for billing tags | - |
| `log_retention_days` | CloudWatch log retention period | 30 |

## Advantages of Terraform/Terragrunt

### 1. **Better State Management**
- Isolated state files per environment
- State locking with DynamoDB
- Remote state in S3

### 2. **Environment Consistency**
- Shared module with environment-specific inputs
- Consistent resource naming and tagging
- Easy to add new environments

### 3. **Developer Experience**
- Local development and testing
- Plan before apply
- Better error messages and rollback

### 4. **CI/CD Integration**
- Can be integrated with existing Terragrunt workflows
- Supports both manual and automated deployments
- Better drift detection

## Rollback Plan

If issues occur with the new Terraform deployment:

1. **Keep the old CloudFormation stack** until fully validated
2. **Use CloudFormation for immediate rollback**:
   ```bash
   # Redeploy the original CloudFormation stack
   aws cloudformation create-stack \
     --stack-name dev-snowflake-rds-dns-resolver \
     --template-body file://cloudformation/resources.yml \
     --parameters ParameterKey=Environment,ParameterValue=dev \
                  ParameterKey=Capability,ParameterValue=rds-dns-resolver \
                  # ... other parameters
   ```

3. **Clean up Terraform resources**:
   ```bash
   ./deploy.sh digitalnp dev destroy --auto-approve
   ```

## Testing Checklist

- [ ] Lambda function deploys successfully
- [ ] EventBridge rule is created and enabled
- [ ] Lambda has correct IAM permissions
- [ ] CloudWatch log group is created
- [ ] Manual Lambda invocation works
- [ ] EventBridge triggers Lambda on RDS restart
- [ ] Target registration in NLB works
- [ ] CloudWatch logs show successful execution

## Support

For issues during migration:
1. Check the deployment logs
2. Verify IAM permissions
3. Test Lambda function manually
4. Review CloudWatch logs
5. Contact the One Data team for assistance
