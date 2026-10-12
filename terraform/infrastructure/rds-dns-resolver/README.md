# RDS DNS Resolver Lambda - Multi-Instance Terraform Module

This Terraform module creates Lambda functions that automatically register RDS instance IP addresses with their corresponding Network Load Balancer target groups when RDS instances are restarted.

## 🎯 Key Features

- **Multi-Instance Support**: Handle multiple RDS instances, each with their own Private Link NLB
- **Flexible Configuration**: Easy to add/remove RDS-NLB pairs
- **Individual Monitoring**: Separate Lambda functions and logs for each RDS instance
- **Event-Driven**: Automatic triggering on RDS restart events
- **Manual Testing**: Support for manual Lambda invocation

## 📋 Overview

The module creates the following resources **for each RDS-NLB pair**:
- **Lambda Function**: Handles RDS IP resolution and NLB target registration
- **CloudWatch Log Group**: Stores Lambda execution logs
- **EventBridge Rule**: Triggers Lambda on specific RDS restart events
- **Lambda Permission**: Allows EventBridge to invoke the Lambda

**Shared resources**:
- **IAM Role & Policy**: Provides necessary permissions for all Lambda functions

## 🏗️ Architecture

```
RDS Instance 1 Restart → EventBridge → Lambda Function 1 → NLB 1 Target Group
RDS Instance 2 Restart → EventBridge → Lambda Function 2 → NLB 2 Target Group
RDS Instance N Restart → EventBridge → Lambda Function N → NLB N Target Group
                                           ↓
                                    CloudWatch Logs
```

## 🚀 Usage

### 1. Configure RDS-NLB Mappings

Edit the Terragrunt configuration file for your environment:

```bash
# For Digital NP Dev
vim environments/digitalnp/dev/terragrunt.hcl
```

Update the `rds_nlb_mappings` section:

```hcl
rds_nlb_mappings = {
  "primary-db" = {
    db_identifier    = "my-primary-rds-instance"
    private_link_nlb = "primary-nlb-name"
    port            = 5432
    description     = "Primary Snowflake database"
  }
  
  "analytics-db" = {
    db_identifier    = "my-analytics-rds-instance"
    private_link_nlb = "analytics-nlb-name"
    port            = 5432
    description     = "Analytics database"
  }
  
  "reporting-db" = {
    db_identifier    = "my-reporting-rds-instance"
    private_link_nlb = "reporting-nlb-name"
    port            = 3306  # MySQL example
    description     = "Reporting database"
  }
}
```

### 2. Deploy with Terragrunt

```bash
# Using the helper script
./deploy.sh digitalnp dev plan    # Review changes
./deploy.sh digitalnp dev apply   # Deploy

# Or manually
cd environments/digitalnp/dev
terragrunt init
terragrunt plan
terragrunt apply
```

### 3. Verify Deployment

```bash
# Check all Lambda functions
terragrunt output rds_dns_resolver_lambda_functions

# Check RDS-NLB mappings summary
terragrunt output rds_nlb_mappings_summary
```

## 📝 Configuration Reference

### RDS-NLB Mapping Object

```hcl
"unique-key" = {
  db_identifier    = string  # RDS DB instance identifier (required)
  private_link_nlb = string  # Private Link NLB name (required)
  port            = number   # Target port (optional, default: 5432)
  description     = string   # Description for documentation (optional)
}
```

### Example Configurations

#### Single Database
```hcl
rds_nlb_mappings = {
  "main-db" = {
    db_identifier    = "prod-snowflake-db"
    private_link_nlb = "prod-snowflake-nlb"
    port            = 5432
    description     = "Production Snowflake database"
  }
}
```

#### Multiple Databases
```hcl
rds_nlb_mappings = {
  "snowflake-prod" = {
    db_identifier    = "snowflake-prod-instance"
    private_link_nlb = "snowflake-prod-nlb"
    port            = 5432
    description     = "Production Snowflake"
  }
  
  "snowflake-staging" = {
    db_identifier    = "snowflake-staging-instance"
    private_link_nlb = "snowflake-staging-nlb"
    port            = 5432
    description     = "Staging Snowflake"
  }
  
  "mysql-analytics" = {
    db_identifier    = "mysql-analytics-instance"
    private_link_nlb = "mysql-analytics-nlb"
    port            = 3306
    description     = "MySQL Analytics DB"
  }
}
```

## 🧪 Testing

### Manual Lambda Testing

Each Lambda function can be tested individually:

```bash
# Test specific Lambda function
aws lambda invoke \
  --function-name dev-snowflake-rds-dns-resolver-primary-db-lambda \
  --payload '{"region":"ap-southeast-2","db_identifier":"my-rds-instance","privatelink_nlb":"my-nlb-name","port":5432}' \
  response.json

# Check response
cat response.json
```

### Test All Lambda Functions

```bash
# Get all function names
terragrunt output rds_dns_resolver_lambda_functions

# Test each function with its configured values
for key in primary-db analytics-db; do
  echo "Testing $key Lambda function..."
  aws lambda invoke \
    --function-name "dev-snowflake-rds-dns-resolver-${key}-lambda" \
    --payload '{}' \
    "response-${key}.json"
done
```

## 📊 Monitoring

### CloudWatch Logs

Each Lambda function has its own log group:
```
/aws/lambda/{environment}-{project}-rds-dns-resolver-{key}-lambda
```

Examples:
- `/aws/lambda/dev-snowflake-rds-dns-resolver-primary-db-lambda`
- `/aws/lambda/dev-snowflake-rds-dns-resolver-analytics-db-lambda`

### EventBridge Rules

Each RDS instance has its own EventBridge rule:
- **Rule Name**: `{environment}-{project}-rds-dns-resolver-{key}-lambda-trigger-rule`
- **Monitors**: Specific RDS instance restart events
- **Triggers**: Corresponding Lambda function

## 🔧 Adding New RDS-NLB Pairs

### Step 1: Update Configuration

Add a new entry to `rds_nlb_mappings`:

```hcl
rds_nlb_mappings = {
  # Existing mappings...
  
  "new-database" = {
    db_identifier    = "my-new-rds-instance"
    private_link_nlb = "my-new-nlb"
    port            = 5432
    description     = "New database for feature X"
  }
}
```

### Step 2: Apply Changes

Run the deploy workflow.

### Step 3: Verify

```bash
# Check new Lambda function
aws lambda get-function --function-name dev-snowflake-rds-dns-resolver-new-database-lambda

# Check new EventBridge rule
aws events describe-rule --name dev-snowflake-rds-dns-resolver-new-database-lambda-trigger-rule
```

## 🗑️ Removing RDS-NLB Pairs

### Step 1: Remove from Configuration

Remove the entry from `rds_nlb_mappings` in your Terragrunt file.

### Step 2: Apply Changes

Run the destroy workflow

## 📈 Outputs

| Output | Description |
|--------|-------------|
| `rds_dns_resolver_lambda_functions` | Map of all Lambda function details |
| `eventbridge_rules` | Map of all EventBridge rule details |
| `cloudwatch_log_groups` | Map of all CloudWatch log group details |
| `rds_nlb_mappings_summary` | Summary of all configured RDS-NLB pairs |

## 🔍 Troubleshooting

### Common Issues

1. **Lambda fails with permission errors**
   - Check IAM role permissions
   - Verify deployment role has necessary permissions

2. **Target registration fails for specific database**
   - Verify RDS instance identifier is correct
   - Check if NLB name matches exactly
   - Ensure target group exists for the NLB

3. **EventBridge not triggering for specific database**
   - Verify RDS instance identifier in EventBridge rule
   - Check if EventBridge rule is enabled
   - Confirm RDS instance is generating restart events

### Debugging Specific Instances

```bash
# Check logs for specific Lambda function
aws logs tail /aws/lambda/dev-snowflake-rds-dns-resolver-primary-db-lambda --follow

# Check EventBridge rule for specific database
aws events describe-rule --name dev-snowflake-rds-dns-resolver-primary-db-lambda-trigger-rule

# List targets for specific rule
aws events list-targets-by-rule --rule dev-snowflake-rds-dns-resolver-primary-db-lambda-trigger-rule
```

## 🚀 Benefits of Multi-Instance Design

### Scalability
- ✅ Easy to add new RDS-NLB pairs
- ✅ Independent scaling per database
- ✅ No single point of failure

### Maintainability
- ✅ Isolated logs per database
- ✅ Independent testing per instance
- ✅ Clear resource organization

### Flexibility
- ✅ Different ports per database
- ✅ Database-specific configurations
- ✅ Independent lifecycle management

## 📚 Migration from Single Instance

If migrating from the single-instance version:

1. **Backup current configuration**
2. **Update Terragrunt file** to use `rds_nlb_mappings`
3. **Plan the changes** to see resource recreation
4. **Apply gradually** or during maintenance window
5. **Verify all databases** are working correctly

The new multi-instance design provides better scalability and maintainability for managing multiple RDS instances with their corresponding Private Link NLBs.

# RDS DNS Resolver GitHub Actions Workflows

This document describes the GitHub Actions workflows for deploying and managing the RDS DNS Resolver infrastructure using Terragrunt.

## 📋 Available Workflows

### 1. **Deploy RDS DNS Resolver** (`deploy-rds-dns-resolver.yml`)

Main deployment workflow for RDS DNS Resolver infrastructure.

**Inputs:**

- `aws-account`: AWS account to deploy to (corenp, coreprd, digitalnp, digitalprd, datanp, management)
- `environment`: Environment (dev, tst, prf, pst, prd)
- `no-execute-changeset`: Dry run mode (default: false)

**Features:**

- ✅ Account and environment validation
- ✅ Approval gates for production
- ✅ Dry run support
- ✅ Lambda function testing after deployment
- ✅ Comprehensive deployment summary

### 2. **Destroy RDS DNS Resolver** (`destroy-rds-dns-resolver.yml`)

Workflow for safely destroying RDS DNS Resolver infrastructure.

**Inputs:**

- `aws-account`: AWS account to destroy from
- `environment`: Environment to destroy
- `dry-run`: Show what would be destroyed (default: true)
- `auto-approve`: Skip confirmation (default: false)

**Features:**

- ✅ Production approval gates
- ✅ Dry run mode by default
- ✅ Manual confirmation required
- ✅ Resource verification after destruction

### 3. **Deploy Infrastructure** (`deploy-infrastructure.yml`)

Single workflow for deploying both PrivateLink and RDS DNS Resolver.

**Inputs:**

- `infrastructure-type`: privatelink, rds-dns-resolver
- `aws-account`: AWS account
- `environment`: Environment
- `no-execute-changeset`: Dry run mode

**Features:**

- ✅ Deploy PrivateLink and RDS DNS Resolver
- ✅ Sequential deployment (PrivateLink first, then RDS DNS Resolver)
- ✅ Combined deployment summary

### 4. **Reusable Workflows**

- `reusable-rds-dns-resolver.yml`: Core deployment logic
- `reusable-rds-dns-resolver-destroy.yml`: Core destruction logic

## 🔧 Configuration

### Account Configuration (`rds-dns-resolver-accounts.json`)

```json
{
  "accounts": {
    "digitalnp": {
      "account_id": "570723136177",
      "environments": ["dev", "pst"],
      "runner_type": "non-prod",
      "description": "Digital Non-Production Account",
      "terragrunt_path": "terraform/infrastructure/rds-dns-resolver/environments/digitalnp",
      "requires_approval": false
    },
    "digitalprd": {
      "account_id": "597924334156",
      "environments": ["prd"],
      "runner_type": "prod",
      "description": "Digital Production Account",
      "terragrunt_path": "terraform/infrastructure/rds-dns-resolver/environments/digitalprd",
      "requires_approval": true
    }
  }
}
```

## 🚀 Usage Examples

### Deploy to Non-Production

```yaml
# Manual trigger via GitHub UI
Workflow: Deploy RDS DNS Resolver
Inputs:
  - aws-account: digitalnp
  - environment: dev
  - no-execute-changeset: false
```

### Deploy to Production

```yaml
# Manual trigger via GitHub UI
Workflow: Deploy RDS DNS Resolver
Inputs:
  - aws-account: digitalprd
  - environment: prd
  - no-execute-changeset: false
```

### Dry Run

```yaml
# Test deployment without making changes
Workflow: Deploy RDS DNS Resolver
Inputs:
  - aws-account: digitalnp
  - environment: dev
  - no-execute-changeset: true
```

## 📊 Workflow Features

### Validation & Safety

- ✅ **Account Validation**: Ensures valid account-environment combinations
- ✅ **Path Verification**: Confirms Terragrunt configuration exists
- ✅ **Placeholder Detection**: Warns about unconfigured values
- ✅ **Approval Gates**: Mandatory for production environments

### Deployment Process

1. **Configuration Validation**: Load and validate account settings
2. **Terragrunt Init**: Initialize Terraform backend
3. **Terragrunt Validate**: Validate configuration syntax
4. **Terragrunt Plan**: Show planned changes
5. **Approval Gate** (production only): Manual approval required
6. **Terragrunt Apply**: Apply changes to infrastructure
7. **Lambda Testing**: Test deployed Lambda functions
8. **Output Display**: Show Terragrunt outputs

### Monitoring & Feedback

- 📊 **Deployment Summary**: Comprehensive status report
- 🧪 **Lambda Testing**: Automatic function testing after deployment
- 📋 **Resource Outputs**: Display created resources and configurations
- 🔍 **Validation Results**: Show configuration validation results

## 🛠️ Troubleshooting

### Common Issues

#### 1. **Placeholder Values Found**

```
❌ Found placeholder values in configuration:
REPLACE_WITH_YOUR_RDS_INSTANCE_NAME
```

**Solution**: Update your Terragrunt configuration with actual values.

#### 2. **IAM Permission Errors**

```
❌ User/Role is not authorized to perform: lambda:CreateFunction. Check the GithubRunnerRole
```

**Solution**: Update IAM policy resource patterns to match actual resource names.

#### 3. **Terragrunt Path Not Found**

```
❌ Terragrunt path not found: terraform/infrastructure/rds-dns-resolver/environments/digitalnp/dev
```

**Solution**: Ensure the environment directory and terragrunt.hcl file exist.

### Debugging Steps

1. **Check Workflow Logs**: Review detailed execution logs in GitHub Actions
2. **Validate Configuration**: Run dry run mode to test configuration
3. **Verify IAM Permissions**: Ensure deployment role has required permissions
4. **Test Locally**: Use the `deploy.sh` script for local testing
5. **Check Terragrunt Config**: Verify terragrunt.hcl syntax and values

## 🔄 Migration from CloudFormation Workflows

### Differences from CloudFormation Workflows

| Aspect | CloudFormation | Terragrunt |
|--------|---------------|------------|
| **Tool** | AWS CloudFormation | Terragrunt + Terraform |
| **State Management** | CloudFormation Stack | Terraform State in S3 |
| **Configuration** | YAML parameters | HCL configuration |
| **Multi-Instance** | Single RDS-NLB pair | Multiple RDS-NLB pairs |
| **Testing** | Manual | Automated Lambda testing |

### Migration Steps

1. **Deploy Terragrunt version** alongside existing CloudFormation
2. **Test thoroughly** in non-production environments
3. **Migrate production** during maintenance window
4. **Remove CloudFormation workflows** after validation

## 📚 Related Documentation

- [Multi-Instance RDS DNS Resolver Features](../../terraform/infrastructure/rds-dns-resolver/MULTI-INSTANCE-FEATURES.md)
- [Terraform Module README](../../terraform/infrastructure/rds-dns-resolver/README.md)
- [Migration Guide](../../terraform/infrastructure/rds-dns-resolver/MIGRATION.md)
- [PrivateLink Workflows](./README-PRIVATELINK.md)

## 🎯 Best Practices

### Deployment Best Practices

1. **Always test in non-production first**
2. **Use dry run mode** to preview changes
3. **Provide meaningful approval comments** for production
4. **Monitor Lambda functions** after deployment
5. **Keep Terragrunt configurations** up to date

### Security Best Practices

1. **Use least privilege IAM policies**
2. **Enable approval gates** for production
3. **Audit deployment logs** regularly
5. **Review resource configurations** before deployment

### Operational Best Practices

1. **Document configuration changes**
2. **Test Lambda functions** after deployment
3. **Monitor CloudWatch logs** for errors
4. **Keep deployment workflows** updated
5. **Maintain environment parity** across accounts
