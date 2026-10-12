# Testing Infrastructure

This directory contains comprehensive testing tools for the Empower Data Acquisition infrastructure.

## Quick Start

```bash
# Interactive test runner
./test/run-tests.sh

# Or run specific tests directly:
./test/validate-syntax.sh              # Syntax validation (no dependencies)
./test/manual-config-test.sh           # Configuration validation (no dependencies)
cd test/localstack && ./simple-test.sh # CLI test (requires LocalStack)
cd test/localstack && ./test.sh        # Full Docker test (requires Docker)
```

## Test Types

### 1. Syntax Validation (`validate-syntax.sh`)
- **Purpose**: Validate Terraform/Terragrunt syntax and structure
- **Dependencies**: Terraform CLI
- **Duration**: ~30 seconds
- **Coverage**: HCL syntax, file structure, configuration completeness

### 2. Manual Configuration Test (`manual-config-test.sh`)
- **Purpose**: Validate configuration logic and settings
- **Dependencies**: None (bash only)
- **Duration**: ~15 seconds
- **Coverage**: Module references, environment configs, data sources, security settings

### 3. LocalStack CLI Test (`localstack/simple-test.sh`)
- **Purpose**: Basic AWS service interaction testing
- **Dependencies**: LocalStack CLI, AWS CLI
- **Duration**: ~1-2 minutes
- **Coverage**: S3 buckets, IAM roles, Secrets Manager, file operations

### 4. LocalStack Docker Test (`localstack/test.sh`)
- **Purpose**: Comprehensive infrastructure testing with Lambda execution
- **Dependencies**: Docker, Terraform, AWS CLI
- **Duration**: ~2-3 minutes
- **Coverage**: Full AWS service emulation, Lambda triggers, end-to-end workflow

## Documentation

See [LOCALSTACK_TESTING.md](../docs/LOCALSTACK_TESTING.md) for comprehensive testing guide including:
- Detailed setup instructions
- Troubleshooting guide
- Test scenarios and use cases
- CI/CD integration examples
- Best practices and performance tips

## Test Results

All tests validate the Empower Data Acquisition infrastructure:
- ✅ S3 Infrastructure (DD-5665)
- ✅ Lambda Validation (DD-5667) 
- ✅ Slack Integration (DD-5668)
- ✅ Multi-environment support (datanp + dataprd)
- ✅ Security configurations
- ✅ GitHub workflow compatibility
