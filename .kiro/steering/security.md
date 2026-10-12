# Security Standards

## Authentication & Authorization
- **AWS OIDC**: GitHub Actions use OIDC for role assumption
- **Cross-Account Access**: IAM roles with least privilege principle
- **Multi-Account Strategy**: Separate accounts for isolation and security boundaries

## Data Protection
- **Encryption**: KMS encryption for S3 buckets and sensitive data
- **Secrets Management**: AWS Secrets Manager for all credentials and passwords
- **Cross-Account S3**: Secure bucket policies for data sharing between accounts
- **Financial Data**: Compliance with financial services data handling requirements

## Input Validation
- **Lambda Functions**: Validate S3 event triggers and file formats
- **Report Processing**: Regex validation for file naming patterns
- **Parameter Files**: JSON schema validation for delivery configurations

## Secrets Management
- **AWS Secrets Manager**: All passwords, API keys, and credentials
- **No Hardcoded Secrets**: Zero tolerance for secrets in code or configuration
- **Environment Variables**: Use for non-sensitive configuration only
- **Rotation**: Implement secret rotation policies where applicable

## Logging & Monitoring
- **CloudWatch Logs**: All Lambda execution logs
- **DMS Monitoring**: CloudWatch subscription filters for DMS tasks
- **Security Events**: Log all cross-account access and role assumptions
- **PII Protection**: Never log sensitive customer data or credentials
- **Audit Trail**: Maintain logs for compliance and troubleshooting
