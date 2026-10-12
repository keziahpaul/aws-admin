# Convert DMS Task CloudFormation to Terraform

## Problem
Convert existing `onedata-exchange-resources-core-DMS-full-cdc` CloudFormation template (36KB, 108 tables, 8 parallel load configs) to Terraform for infrastructure modernization.

## Requirements

### Core Conversion
- Convert AWS::DMS::ReplicationConfig to aws_dms_replication_config
- Preserve all 108 table selection rules (rule-id 1-108) exactly
- Maintain 8 parallel load configurations (rule-id 109-116) with boundaries
- Keep identical compute config (MultiAZ, MinDCU/MaxDCU, maintenance window)
- Preserve security group imports and VPC subnet configurations

### Environment Support
- Support dev, tst, pst, prf, prd environments
- Maintain existing .properties parameter file structure
- Cross-account endpoint ARN patterns preserved
- Environment-specific tags and configurations

### Deployment Integration
- New GitHub workflow: `onedata-exchange-resources-core-DMS-full-cdc-terraform-deploy.yml`
- Terraform file structure: `terraform/infrastructure/onedata-exchange-resources-core-DMS-full-cdc/`
- Zero downtime migration with rollback capability
- Compatible with existing CloudFormation exports during transition

## Constraints
- AWS Provider ~> 5.0, Terraform >= 1.0
- ap-southeast-2 region only
- Multi-account support (Data, Core, Digital, Management)
- No production disruption, financial services compliance
- Existing GitHub Actions runners and OIDC authentication

## Acceptance Criteria
- [ ] Identical DMS replication task configuration
- [ ] All 116 table mapping rules preserved exactly
- [ ] Security group and subnet references functional
- [ ] Task ARN output matches CloudFormation format
- [ ] All environments deploy successfully
- [ ] Performance metrics match existing task
- [ ] Rollback procedure tested

## Technical Notes
- Critical: Exact JSON preservation of table mappings structure
- Security groups via data source or variable (not Fn::ImportValue)
- Cross-account endpoint ARNs with account ID substitution
- Side-by-side deployment for validation before migration
