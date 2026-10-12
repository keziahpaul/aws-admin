# PEXA One Data AWS Infrastructure

This repository contains Terragrunt-managed infrastructure for PEXA's One Data platform.

## Structure

```
terraform/
├── terragrunt.hcl                    # Root configuration
├── infrastructure/                   # Service-specific deployments
│   └── privatelink/                 # PrivateLink infrastructure
│       ├── terragrunt.hcl          # Infrastructure-level config
│       ├── main.tf                 # External module composition
│       ├── variables.tf            # Input variables
│       ├── outputs.tf              # Output values
│       ├── pre-destroy.sh          # Cleanup script
│       └── environments/           # Environment-specific configs
│           ├── corenp/
│           │   ├── dev/terragrunt.hcl
│           │   ├── tst/terragrunt.hcl
│           │   └── prf/terragrunt.hcl
│           ├── coreprd/terragrunt.hcl
│           ├── digitalnp/
│           │   ├── dev/terragrunt.hcl
│           │   └── pst/terragrunt.hcl
│           ├── digitalprd/terragrunt.hcl
│           └── management/terragrunt.hcl
└── shared/                          # Cross-cutting resources (future use)
    ├── dns/                        # Shared DNS resources
    └── networking/                 # Shared networking resources
```

## Architecture

### External Module Approach
This infrastructure uses external Git modules from PEXA's module registry:
- **PrivateLink**: `git@github.com:PEXA-AU/aws-privatelink.git//privatelink?ref=1.0.8`
- **Future modules**: VPC endpoints, DNS, RDS, Lambda, etc. will be sourced from Git

### Benefits
- **No duplication**: Direct use of external modules without wrapper layers
- **Version control**: Pinned module versions for stability
- **Centralized modules**: Shared across multiple repositories
- **Reduced maintenance**: No local module maintenance overhead

## Usage

### Deploy PrivateLink Infrastructure

```bash
# Navigate to specific environment
cd infrastructure/privatelink/environments/corenp/dev

# Plan deployment
terragrunt plan

# Apply deployment
terragrunt apply

# Destroy deployment (with cleanup)
../../../pre-destroy.sh  # Run cleanup first
terragrunt destroy
```

### Deploy All Environments

```bash
# From the infrastructure/privatelink directory
terragrunt run-all plan
terragrunt run-all apply
```

### Environment-Specific Operations

```bash
# Deploy only corenp environments
cd infrastructure/privatelink/environments/corenp
terragrunt run-all plan
terragrunt run-all apply

# Deploy specific environment
cd infrastructure/privatelink/environments/corenp/dev
terragrunt plan
terragrunt apply
```

## Adding New Infrastructure

### 1. Create New Service Infrastructure
For new services (e.g., data platform, ML platform), create new infrastructure directories:

```bash
mkdir -p infrastructure/data-platform
cd infrastructure/data-platform

# Create main.tf with external module references
cat > main.tf << 'EOF'
module "rds" {
  source = "git@github.com:PEXA-AU/aws-rds.git//rds?ref=1.0.0"
  # ... configuration
}

module "s3" {
  source = "git@github.com:PEXA-AU/aws-s3.git//s3?ref=1.0.0"
  # ... configuration
}

module "lambda" {
  source = "git@github.com:PEXA-AU/aws-lambda.git//lambda?ref=1.0.0"
  # ... configuration
  s3_bucket = module.s3.bucket_name
  db_endpoint = module.rds.endpoint
}
EOF

# Add variables.tf, outputs.tf, terragrunt.hcl
# Create environments/ directory structure
```

### 2. Environment Configuration
Each environment should have its own `terragrunt.hcl` with:
- Unique S3 state key path
- Environment-specific variables
- Correct source path to infrastructure directory

Example environment config:
```hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../.."  # Points to infrastructure/service-name/
}

remote_state {
  backend = "s3"
  config = {
    bucket = "remote-tfstate-ap-southeast-2-ACCOUNT-ID"
    key    = "infrastructure/service-name/environment/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

inputs = {
  environment = "dev"
  # ... other variables
}
```

## Current Environments

### PrivateLink Service
- **corenp**: dev, tst, prf (Account: 526552200036)
- **coreprd**: prd (Account: 215597176832)
- **digitalnp**: dev, pst (Account: 570723136177)
- **digitalprd**: prd (Account: 597924334156)
- **management**: prd (Account: 004761221582)

### Service Purposes
- **fivetran environments**: Database connectivity (PostgreSQL port 5432)
- **management/alation**: HTTPS connectivity (port 443)

## Key Features

- **External Module Integration**: Direct use of PEXA's Git-based modules
- **Environment Isolation**: Separate state files per environment
- **Cross-Account Support**: Different AWS accounts per environment
- **DRY Configuration**: Common settings in root terragrunt.hcl
- **Scalable Structure**: Easy to add new services and environments
- **Version Pinning**: Controlled module versions for stability

## Migration Notes

This structure has been migrated from the original `terraform/privatelink/` layout to:
- **Eliminate redundancy**: Removed unnecessary local module wrappers
- **Improve clarity**: Direct external module references
- **Enable scaling**: Infrastructure-based organization for multiple services

## Future Roadmap

1. **Add VPC Endpoint Infrastructure**: Create `infrastructure/vpc-endpoints/`
2. **Add DNS Management**: Create `infrastructure/dns/`
3. **Add Data Platform**: Create `infrastructure/data-platform/` (RDS + S3 + Lambda)
4. **Add ML Platform**: Create `infrastructure/ml-platform/` (SageMaker + Bedrock)
5. **Add Event Processing**: Create `infrastructure/event-processing/` (Lambda + EventBridge)

## Best Practices

- **Pin module versions**: Always specify `?ref=x.y.z` for external modules
- **Environment isolation**: Each environment has its own state file
- **Consistent naming**: Follow `infrastructure/service-name/environments/account/env/` pattern
- **Pre-destroy cleanup**: Use cleanup scripts before destroying infrastructure
- **State key organization**: Use descriptive state key paths for easy identification
