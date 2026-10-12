# DMS Task Exchange - Terraform Module

## Overview
This Terraform module creates a DMS Serverless replication task for full load and CDC replication of 108 PEXA database tables with optimized parallel loading configurations.

## Features
- Full load and CDC replication for 108 PEXA tables
- 8 parallel load configurations for performance optimization
- Multi-environment support (dev, tst, pst, prf, prd)
- Cross-account endpoint support
- Identical configuration to CloudFormation template

## Structure

### Legacy Structure (tfvars)
```
environments/
├── dev.tfvars
├── tst.tfvars
├── pst.tfvars
├── prf.tfvars
└── prd.tfvars
```

### New Structure (Terragrunt)
```
environments/
├── dev/
│   ├── terragrunt.hcl
│   └── table_mappings.json
├── tst/
│   ├── terragrunt.hcl
│   └── table_mappings.json
├── pst/
│   ├── terragrunt.hcl
│   └── table_mappings.json
├── prf/
│   ├── terragrunt.hcl
│   └── table_mappings.json
└── prd/
    ├── terragrunt.hcl
    └── table_mappings.json
```

## Usage

### Using Terragrunt (Recommended)
```bash
# Navigate to environment directory
cd terraform/infrastructure/onedata-exchange-resources-core-DMS-full-cdc/environments/dev

# Plan deployment
terragrunt plan

# Apply changes
terragrunt apply
```

### Using Terraform (Legacy)
```bash
# Navigate to module directory
cd terraform/infrastructure/onedata-exchange-resources-core-DMS-full-cdc

# Plan deployment
terraform plan -var-file=environments/dev.tfvars

# Apply changes
terraform apply -var-file=environments/dev.tfvars
```

### Module Usage
```hcl
module "dms_task_exchange" {
  source = "./terraform/infrastructure/onedata-exchange-resources-core-DMS-full-cdc"
  
  environment        = "dev"
  account           = "526552200036"
  onedata_account   = "042775015153"
  min_dcu          = 1
  max_dcu          = 2
  dms_subnet_group = "default-vpc-a10bc2c5"
  security_group_id = "sg-046190cc731d90dc4"
}
```

## Variables

| Name | Description | Type | Required |
|------|-------------|------|----------|
| environment | Environment name (dev, tst, pst, prf, prd) | string | yes |
| account | AWS Account ID | string | yes |
| onedata_account | Onedata AWS Account ID | string | yes |
| min_dcu | Minimum Data Capacity Units | number | yes |
| max_dcu | Maximum Data Capacity Units | number | yes |
| dms_subnet_group | DMS Subnet Group ID | string | yes |
| security_group_id | Security Group ID | string | yes |
| project | Project name | string | no |
| cost_centre | Cost centre for billing | string | no |
| aws_region | AWS region | string | no |

## Outputs

| Name | Description |
|------|-------------|
| dms_task_arn | DMS Serverless replication task ARN |

## Environment Configuration

Each environment has specific configurations:

- **dev**: Development environment (non-prod account)
- **tst**: Test environment (non-prod account)
- **pst**: Pre-staging environment (non-prod account)
- **prf**: Performance environment (non-prod account)
- **prd**: Production environment (prod account)

## Workflows

- **Legacy**: `.github/workflows/onedata-exchange-resources-core-DMS-full-cdc-terraform-deploy.yml`
- **Terragrunt**: `.github/workflows/onedata-exchange-resources-core-DMS-full-cdc-terragrunt-deploy.yml`

## Table Mappings
- **108 selection rules**: All pxa_* tables from PEXA schema
- **8 table-settings rules**: Parallel load configurations with range boundaries for performance optimization

## Migration Path

1. Both tfvars and terragrunt structures are supported
2. New deployments should use terragrunt approach
3. Legacy workflow remains for backward compatibility
4. Gradual migration to terragrunt recommended

## Migration from CloudFormation
This module provides identical functionality to the CloudFormation template `onedata-exchange-resources-core-DMS-full-cdc.yml` with zero configuration changes.
