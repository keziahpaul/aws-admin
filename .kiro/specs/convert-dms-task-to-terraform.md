# Convert DMS Task CloudFormation to Terraform

## Overview
Convert the `onedata-exchange-resources-core-DMS-task.yml` CloudFormation template to Terraform, maintaining all existing settings, connections, and security groups while renaming the job to `dev-onedata-exchange-set2-serverless-full-cdc`.

## Requirements

### Core Conversion
- Convert AWS::DMS::ReplicationConfig to aws_dms_replication_config resource
- Maintain all existing parameters as Terraform variables
- Preserve all table mappings and parallel load configurations
- Keep identical security group references and subnet configurations
- Rename job identifier to `dev-onedata-exchange-set2-serverless-full-cdc`

### Configuration Preservation
- **Compute Config**: MultiAZ, MinDCU/MaxDCU scaling, maintenance window
- **Replication Settings**: Logging, target metadata, full load settings
- **Table Mappings**: All 14 selection rules and 6 table-settings rules with parallel load boundaries
- **Security**: VPC security groups from imported values
- **Endpoints**: Source and target endpoint ARNs with same naming pattern

### File Structure
```
terraform/infrastructure/dms-task-set2/
├── main.tf              # DMS replication config resource
├── variables.tf         # Input variables (Environment, Account, etc.)
├── outputs.tf           # Task ARN output
└── versions.tf          # Terraform and provider requirements
```

## Acceptance Criteria
- [ ] Terraform configuration creates identical DMS replication task
- [ ] All 14 table selection rules preserved exactly
- [ ] All 6 parallel load configurations with boundaries maintained
- [ ] Security group import reference works correctly
- [ ] Task name changed to `dev-onedata-exchange-set2-serverless-full-cdc`
- [ ] All parameters converted to Terraform variables
- [ ] Output exports task ARN for cross-stack references
- [ ] Terraform validates and plans successfully

## Technical Notes
- Use `data.aws_caller_identity.current.account_id` for AWS account ID
- Convert CloudFormation Fn::ImportValue to terraform data source or variable
- Maintain JSON structure for table_mappings exactly as in CloudFormation
- Use terraform locals for repeated values like region and account patterns
