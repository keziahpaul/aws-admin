# Multi-Instance RDS DNS Resolver - Feature Overview

## 🎯 Problem Solved

**Original Limitation**: The CloudFormation template only supported one RDS instance and one Private Link NLB per environment.

**New Capability**: Support multiple RDS instances, each with their own Private Link NLB, all managed from a single Terraform module.

## 🚀 Key Features

### ✅ **Multi-Instance Support**
- Configure multiple RDS-NLB pairs in a single environment
- Each RDS instance gets its own Lambda function
- Independent monitoring and logging per database

### ✅ **Flexible Configuration**
- Easy to add/remove RDS-NLB pairs
- Support for different database ports (PostgreSQL, MySQL, etc.)
- Descriptive naming and documentation per instance

### ✅ **Scalable Architecture**
- Shared IAM role for cost efficiency
- Individual EventBridge rules per RDS instance
- Isolated failure domains per database

### ✅ **Enhanced Monitoring**
- Separate CloudWatch log groups per Lambda function
- Tagged resources for easy identification
- Detailed outputs for operational visibility

## 📋 Configuration Example

### Before (Single Instance)
```hcl
inputs = {
  db_identifier    = "my-single-rds-instance"
  private_link_nlb = "my-single-nlb"
}
```

### After (Multi-Instance)
```hcl
inputs = {
  rds_nlb_mappings = {
    "primary-db" = {
      db_identifier    = "snowflake-prod-primary"
      private_link_nlb = "snowflake-primary-nlb"
      port            = 5432
      description     = "Primary Snowflake database"
    }
    
    "analytics-db" = {
      db_identifier    = "snowflake-analytics"
      private_link_nlb = "snowflake-analytics-nlb"
      port            = 5432
      description     = "Analytics Snowflake database"
    }
    
    "mysql-legacy" = {
      db_identifier    = "legacy-mysql-db"
      private_link_nlb = "mysql-legacy-nlb"
      port            = 3306
      description     = "Legacy MySQL database"
    }
  }
}
```

## 🏗️ Resource Creation

For each RDS-NLB pair, the module creates:

| Resource Type | Purpose | Naming Pattern |
|---------------|---------|----------------|
| **Lambda Function** | DNS resolution and target registration | `{env}-{project}-rds-dns-resolver-{key}-lambda` |
| **CloudWatch Log Group** | Lambda execution logs | `/aws/lambda/{env}-{project}-rds-dns-resolver-{key}-lambda` |
| **EventBridge Rule** | RDS restart event monitoring | `{env}-{project}-rds-dns-resolver-{key}-lambda-trigger-rule` |
| **EventBridge Target** | Lambda invocation configuration | `{env}-{project}-rds-dns-resolver-{key}-lambda-target` |
| **Lambda Permission** | EventBridge invoke permission | Per Lambda function |

**Shared Resources:**
- **IAM Role**: `{env}-{project}-rds-dns-resolver-lambda-role`
- **IAM Policy**: Attached to the shared role

## 📊 Example Deployment

### Configuration
```hcl
rds_nlb_mappings = {
  "snowflake-prod" = {
    db_identifier    = "sf-prod-db"
    private_link_nlb = "sf-prod-nlb"
    port            = 5432
  }
  
  "snowflake-dev" = {
    db_identifier    = "sf-dev-db"
    private_link_nlb = "sf-dev-nlb"
    port            = 5432
  }
}
```

### Resources Created
```
Lambda Functions:
├── dev-snowflake-rds-dns-resolver-snowflake-prod-lambda
└── dev-snowflake-rds-dns-resolver-snowflake-dev-lambda

EventBridge Rules:
├── dev-snowflake-rds-dns-resolver-snowflake-prod-lambda-trigger-rule
└── dev-snowflake-rds-dns-resolver-snowflake-dev-lambda-trigger-rule

CloudWatch Log Groups:
├── /aws/lambda/dev-snowflake-rds-dns-resolver-snowflake-prod-lambda
└── /aws/lambda/dev-snowflake-rds-dns-resolver-snowflake-dev-lambda

Shared IAM Role:
└── dev-snowflake-rds-dns-resolver-lambda-role
```

## 🔧 Operations

### Adding New RDS-NLB Pair
1. Add entry to `rds_nlb_mappings`
2. Run `terragrunt plan` to review changes
3. Run `terragrunt apply` to create resources
4. Test the new Lambda function

### Removing RDS-NLB Pair
1. Remove entry from `rds_nlb_mappings`
2. Run `terragrunt plan` to review deletions
3. Run `terragrunt apply` to remove resources

### Testing All Functions
```bash
./test-all-lambdas.sh dev snowflake
```

## 📈 Benefits

### **Operational Benefits**
- ✅ **Isolated Failures**: One database issue doesn't affect others
- ✅ **Independent Scaling**: Add/remove databases independently
- ✅ **Clear Monitoring**: Separate logs and metrics per database
- ✅ **Easy Troubleshooting**: Focused debugging per instance

### **Cost Benefits**
- ✅ **Shared IAM Role**: Reduced IAM resource costs
- ✅ **Efficient Resource Usage**: Only create what you need
- ✅ **Granular Control**: Remove unused resources easily

### **Development Benefits**
- ✅ **Environment Parity**: Same configuration across environments
- ✅ **Easy Testing**: Test individual databases independently
- ✅ **Clear Documentation**: Self-documenting configuration

## 🔄 Migration Path

### From CloudFormation (Single Instance)
1. **Deploy Terraform version** alongside CloudFormation
2. **Test thoroughly** with existing RDS-NLB pair
3. **Add additional pairs** as needed
4. **Remove CloudFormation stack** once validated

### From Terraform (Single Instance)
1. **Update configuration** to use `rds_nlb_mappings`
2. **Plan changes** to see resource recreation
3. **Apply during maintenance window**
4. **Verify all databases** are working

## 🧪 Testing Strategy

### Individual Testing
```bash
# Test specific Lambda function
aws lambda invoke \
  --function-name dev-snowflake-rds-dns-resolver-primary-db-lambda \
  --payload '{}' \
  response.json
```

### Bulk Testing
```bash
# Test all Lambda functions
./test-all-lambdas.sh dev snowflake
```

### Monitoring
```bash
# Check all function outputs
terragrunt output rds_dns_resolver_lambda_functions

# View configuration summary
terragrunt output rds_nlb_mappings_summary
```

## 🎉 Summary

The multi-instance RDS DNS Resolver provides:

- **Scalability**: Handle multiple databases effortlessly
- **Flexibility**: Support different database types and ports
- **Reliability**: Isolated failure domains per database
- **Maintainability**: Clear resource organization and monitoring
- **Cost Efficiency**: Shared resources where appropriate

This design enables you to manage multiple RDS instances with their corresponding Private Link NLBs from a single, maintainable Terraform configuration while providing the operational benefits of isolated monitoring and independent lifecycle management.
