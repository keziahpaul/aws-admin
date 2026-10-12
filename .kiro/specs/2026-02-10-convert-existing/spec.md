# Convert DMS Task CloudFormation to Terraform

## Problem Statement

The existing DMS task `onedata-exchange-resources-core-DMS-full-cdc` is currently deployed using CloudFormation but needs to be converted to Terraform to align with the infrastructure modernization strategy. The task handles full load and CDC replication for 108 tables from the PEXA database with complex parallel loading configurations.

## Context

- **Current State**: CloudFormation template with 36KB of configuration including 108 table selection rules and 8 parallel load configurations
- **Target State**: Terraform module with identical functionality and configuration
- **Business Impact**: Critical data pipeline for PEXA exchange operations across multiple environments
- **Technical Debt**: Mixed infrastructure tooling (CloudFormation + Terraform) creates maintenance overhead

## Requirements

### Functional Requirements

1. **DMS Replication Configuration**
   - Convert AWS::DMS::ReplicationConfig to aws_dms_replication_config
   - Maintain identical replication settings (full-load-and-cdc)
   - Preserve compute configuration (MultiAZ, MinDCU/MaxDCU, maintenance window)
   - Keep all logging and target metadata settings

2. **Table Mappings Preservation**
   - Convert all 108 selection rules (rule-id 1-108) exactly as JSON structure
   - Maintain all table names and schema references (pexa.pxa_*)
   - Preserve rule naming and ordering

3. **Parallel Load Configuration**
   - Convert 8 table-settings rules (rule-id 109-116) with parallel load boundaries
   - Maintain column references and range values for performance optimization
   - Preserve parallel load type (ranges) and boundary definitions

4. **Networking & Security**
   - Convert security group import to Terraform data source or variable
   - Maintain VPC subnet group configuration
   - Preserve cross-account endpoint ARN patterns

### Non-Functional Requirements

1. **Environment Compatibility**
   - Support all environments: dev, tst, pst, prf, prd
   - Maintain parameter file structure compatibility
   - Preserve environment-specific configurations

2. **Deployment Integration**
   - Create new GitHub workflow for Terraform deployment
   - Maintain existing parameter file locations and formats
   - Support both manual and automated deployments

3. **Operational Continuity**
   - Zero downtime migration approach
   - Rollback capability to CloudFormation if needed
   - Maintain existing monitoring and alerting

## Constraints

### Technical Constraints

- **AWS Provider**: Must use aws provider ~> 5.0
- **Terraform Version**: >= 1.0 compatibility required
- **Regional Deployment**: ap-southeast-2 only
- **Multi-Account**: Support Data, Core, Digital, Management accounts
- **Naming Convention**: Follow existing Terraform module patterns

### Business Constraints

- **Production Impact**: No disruption to existing DMS tasks
- **Migration Timeline**: Phased rollout starting with dev environment
- **Compliance**: Maintain financial services data handling requirements
- **Security**: All secrets via AWS Secrets Manager, no hardcoded values

### Operational Constraints

- **GitHub Actions**: Use existing runner labels ([non-prod, deploy], [prod, deploy])
- **OIDC Authentication**: Maintain existing role assumption patterns
- **Parameter Management**: Keep existing .properties file structure
- **Cross-Stack References**: Maintain CloudFormation export compatibility during transition

## High-Level Design

### File Structure
```
terraform/infrastructure/onedata-exchange-resources-core-DMS-full-cdc/
├── main.tf              # DMS replication config resource
├── variables.tf         # Input variables (Environment, Account, etc.)
├── outputs.tf           # Task ARN output for cross-stack references
├── versions.tf          # Terraform and provider requirements
└── README.md           # Module documentation
```

### Terraform Configuration

1. **Resource Definition**
   - `aws_dms_replication_config` with identical settings to CloudFormation
   - JSON table_mappings block with all 116 rules preserved
   - Compute config with parameterized DCU settings

2. **Variable Structure**
   - Environment-specific variables matching existing parameter files
   - Account ID and cross-account configurations
   - Security group and subnet group references

3. **Output Exports**
   - Task ARN for cross-stack references
   - Compatible with existing CloudFormation import patterns

### Deployment Workflow

1. **GitHub Actions Workflow**
   - New workflow: `deploy-dms-task-exchange-terraform.yml`
   - Trigger on terraform file changes and parameter updates
   - Environment-specific deployment jobs (dev, tst, pst, prf, prd)

2. **Parameter Integration**
   - Convert existing .properties files to Terraform variables
   - Maintain environment-specific configurations
   - Support for cross-account deployments

3. **Migration Strategy**
   - Deploy Terraform alongside CloudFormation initially
   - Validate identical configuration and outputs
   - Switch traffic and remove CloudFormation stack

## Acceptance Criteria

### Core Functionality
- [ ] Terraform configuration creates identical DMS replication task
- [ ] All 108 table selection rules preserved exactly (rule-id 1-108)
- [ ] All 8 parallel load configurations maintained (rule-id 109-116)
- [ ] Security group and subnet references work correctly
- [ ] Task ARN output matches CloudFormation export format

### Environment Support
- [ ] Dev environment deployment successful
- [ ] Parameter files converted and functional
- [ ] Cross-account endpoint ARNs resolve correctly
- [ ] Environment-specific tags applied

### Operational Requirements
- [ ] GitHub workflow deploys successfully
- [ ] Terraform validates and plans without errors
- [ ] Rollback procedure documented and tested
- [ ] Monitoring and alerting maintained

### Migration Validation
- [ ] Side-by-side comparison shows identical configuration
- [ ] Performance metrics match existing task
- [ ] No data loss or replication interruption
- [ ] CloudFormation stack removal successful

## Technical Implementation Notes

### Table Mappings Conversion
The most critical aspect is preserving the exact JSON structure of table mappings:
- 108 selection rules for individual tables
- 8 table-settings rules with parallel load boundaries
- Exact column references and range values for performance

### Security Group Handling
Convert CloudFormation Fn::ImportValue to:
```hcl
data "aws_security_group" "dms_sg" {
  name = "onedata-exchange-dms-security-group-${var.environment}"
}
```

### Cross-Account Endpoint ARNs
Maintain existing pattern:
```hcl
source_endpoint_arn = "arn:aws:dms:ap-southeast-2:${data.aws_caller_identity.current.account_id}:endpoint:onedata-exchange-src-db-${var.environment}"
target_endpoint_arn = "arn:aws:dms:ap-southeast-2:${data.aws_caller_identity.current.account_id}:endpoint:onedata-exchange-tgt-s3-${var.environment}"
```

## Risk Mitigation

### High Risk: Data Pipeline Disruption
- **Mitigation**: Deploy Terraform task alongside CloudFormation initially
- **Validation**: Compare task configurations and test with non-production data
- **Rollback**: Keep CloudFormation stack until Terraform proven stable

### Medium Risk: Parameter File Compatibility
- **Mitigation**: Maintain existing parameter file structure
- **Validation**: Test all environment deployments before production
- **Rollback**: Revert to CloudFormation workflow if issues arise

### Low Risk: GitHub Workflow Integration
- **Mitigation**: Create new workflow without removing existing one
- **Validation**: Test deployment process in dev environment
- **Rollback**: Disable new workflow and use existing CloudFormation process

## Success Metrics

1. **Deployment Success**: All environments deploy without errors
2. **Configuration Parity**: 100% match with existing CloudFormation task
3. **Performance Maintenance**: No degradation in replication performance
4. **Operational Continuity**: Zero downtime during migration
5. **Team Adoption**: Successful handover to operations team

## Dependencies

- AWS Provider ~> 5.0 compatibility
- Existing DMS endpoints and security groups
- GitHub Actions runner availability
- Cross-account IAM role permissions
- Parameter file structure maintenance
