# Technology Stack

## Runtime & Languages
- **Python 3.12**: Lambda runtime for bespoke reporting system
- **HCL**: Terraform/Terragrunt for infrastructure modules
- **YAML**: CloudFormation templates and GitHub workflows

## Frameworks & Libraries
- **AWS SDK (boto3)**: AWS service interactions
- **Python Libraries**: requests, pyzipper, pytz, msal (Microsoft Graph API)
- **Infrastructure**: CloudFormation SAM Transform, Terraform >= 1.0
- **AWS Provider**: ~> 5.0

## Development Tools
- **Package Manager**: pip3 for Python dependencies
- **Build Tools**: zip for Lambda packaging, AWS CLI for deployments
- **Version Control**: Git with commit SHA as Lambda version identifier

## Infrastructure
- **Primary Cloud**: AWS (ap-southeast-2 region)
- **Multi-Account**: Data, Core, Digital, Management accounts
- **Environments**: dev, tst, pst, prf, prd
- **CI/CD**: GitHub Actions with custom runners ([prod, deploy], [non-prod, deploy])
- **Authentication**: AWS OIDC with role assumption

## AWS Services Stack
- **Compute**: Lambda (Python 3.12)
- **Storage**: S3 with cross-account access
- **Security**: IAM, Secrets Manager, KMS encryption
- **Networking**: VPC, PrivateLink, DNS resolver
- **Data**: DMS, Glue, SageMaker
- **Integration**: AppFlow (Salesforce), SES (email delivery)
- **Monitoring**: CloudWatch (DMS subscription filters)

## Technical Constraints
- **Python Version**: 3.12 (Lambda runtime requirement)
- **Terraform Version**: >= 1.0
- **AWS Provider**: ~> 5.0 (avoid breaking changes)
- **Regional Deployment**: ap-southeast-2 only
- **Security**: No hardcoded secrets, all via AWS Secrets Manager
- **Compliance**: Financial services data handling requirements
