[![Build and Push Image](https://github.com/PEXA-AU/pexa-one-data-snowflake-au-common-lib/actions/workflows/build-push-image.yml/badge.svg?branch=main)](https://github.com/PEXA-AU/pexa-one-data-snowflake-au-common-lib/actions/workflows/build-push-image.yml)

[![COMMON SCHEMACHANGE DEPLOY](https://github.com/PEXA-AU/pexa-one-data-snowflake-au-common-lib/actions/workflows/common-schemachange-deploy.yml/badge.svg?branch=main)](https://github.com/PEXA-AU/pexa-one-data-snowflake-au-common-lib/actions/workflows/common-schemachange-deploy.yml)



# PEXA One Data Snowflake AU Common Library

Shared utilities and configurations for ONEData.

## Overview

This repository contains common components used across ONEData Snowflake infrastructure:

- **Utils**: Python utilities for secret management, key generation, and credential updates
- **Schemachange**: Database migration scripts and Jinja2 templates for Snowflake objects
- **Account Scripts**: Account-level configurations and scripts for the different ONEData nodes
- **CI/CD Workflows**: GitHub Actions for automated deployments and builds

## Project Structure

```
├── utils/                          # Python utilities
│   ├── get_secret.py               # AWS Secrets Manager utility
│   ├── generate_rsa_keys.py        # RSA key pair generation
│   ├── generate_scim_tokens.py     # SCIM token generation for Okta
│   └── update_dbt_credentials.py   # Automates credential rotation for DBT
├── config/                         # Configuration files
│   └── snowflake_accounts.json     # Snowflake account definitions
├── schemachange/                   # Database migration framework
│   ├── config/                     # Schemachange configuration
│   ├── modules/                    # Jinja2 templates for Snowflake objects
│   └── scripts/                    # Migration scripts
├── AccountScripts/                 # Account-level scripts
│   ├── exchange/                   # -- nodes
│   ├── group/
│   ├── landinsights/
│   └── value-australia/
├── docs/                           # Documentation
│   └── SCIM_TOKEN_AUTOMATION_README.md
└── tests/                          # Unit tests
```

## Running Tests

### Setup Virtual Environment (macOS)
```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Run Tests
```bash
# Ensure virtual environment is activated
source venv/bin/activate

# Run all tests
python -m pytest tests/ -v

# Run specific test file
python -m pytest tests/test_get_secret.py -v
```

### Deactivate Virtual Environment
```bash
deactivate
```

## Deployment Workflows

This repository includes GitHub Actions workflows for automated deployments:

### Available Workflows
- **Common Schemachange Deploy** - Deploy database changes to common environments
- **Dev Sandbox Deploy** - Deploy to development sandbox environment
- **Test Sandbox Deploy** - Deploy to test sandbox environment
- **Build Push Image** - Build and push Docker images
- **Upload Modules** - Upload Jinja2 modules and configurations
- **Streamlit App Deploy** - Deploy Streamlit applications

## Requirements
- Python 3.6+
- AWS credentials configured
- Snowflake account access
- Docker (for containerized deployments)
- boto3 library