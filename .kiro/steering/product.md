# Product Overview

## Purpose
PEXA One Data AWS Admin provides infrastructure and automation for data processing, reporting, and cross-account resource management across PEXA's AWS multi-account architecture.

## Target Users
- **Data Engineers**: Managing data pipelines, DMS tasks, and ETL processes
- **DevOps Engineers**: Deploying infrastructure across multiple AWS accounts
- **Business Stakeholders**: Receiving automated bespoke reports via email/S3
- **External Partners**: Banks (ANZ, CBA, Westpac, NAB) receiving data extracts

## Key Features
1. **Bespoke Report Automation**: Lambda-based system for processing, formatting, and delivering reports
2. **Multi-Account Infrastructure**: CloudFormation/Terraform for cross-account resource deployment
3. **Data Pipeline Management**: DMS, Glue, and SageMaker infrastructure automation
4. **Secure Data Exchange**: PrivateLink, VPC endpoints, and cross-account S3 access
5. **Partner Integration**: Salesforce AppFlow, Snowflake IAM, and bank-specific data formats

## Business Objectives
- **Automated Reporting**: Reduce manual effort in report generation and delivery
- **Compliance**: Secure data handling with encryption, access controls, and audit trails
- **Scalability**: Support multiple environments and partner integrations
- **Reliability**: Automated deployments with rollback capabilities

## Technical Constraints
- **Multi-Account Architecture**: Resources span Data, Core, Digital, and Management accounts
- **Security**: All secrets in AWS Secrets Manager, no hardcoded credentials
- **Compliance**: Financial services data handling requirements
- **Regional**: Primary deployment in ap-southeast-2 (Sydney)
- **Partner Requirements**: Specific file formats and delivery mechanisms for each bank
