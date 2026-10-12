# Tasks: Convert DMS Task CloudFormation to Terraform

## Task 1: Create Terraform File Structure
- [x] Create `terraform/infrastructure/dms-task-set2/` directory
- [x] Create `versions.tf` with Terraform and AWS provider requirements
- [x] Create `variables.tf` with all CloudFormation parameters as variables
- [x] Create `outputs.tf` for task ARN export

## Task 2: Convert Core DMS Resource
- [x] Convert AWS::DMS::ReplicationConfig to aws_dms_replication_config
- [x] Set replication_config_identifier to `dev-onedata-exchange-set2-serverless-full-cdc`
- [x] Configure compute_config with MultiAZ, MinDCU/MaxDCU, maintenance window
- [x] Set replication_type to "full-load-and-cdc"

## Task 3: Convert Replication Settings
- [x] Convert replication_settings block with logging enabled
- [x] Set target_metadata with LobMaxSize: 16384
- [x] Configure full_load_settings with MaxFullLoadSubTasks: 24
- [x] Set TargetTablePrepMode to "DO_NOTHING"

## Task 4: Convert Table Mappings
- [x] Convert all 14 selection rules exactly as JSON structure
- [x] Preserve all table names and schema references
- [x] Maintain rule-id numbering from 1-14

## Task 5: Convert Parallel Load Settings
- [x] Convert 6 table-settings rules (rule-id 15-20)
- [x] Preserve all parallel load boundaries exactly
- [x] Maintain column references and range values

## Task 6: Configure Networking & Security
- [x] Convert security group import to data source or variable
- [x] Set replication_subnet_group_id from DMSSubnetGroup parameter
- [x] Configure vpc_security_group_ids array

## Task 7: Set Endpoints and Tags
- [x] Configure source_endpoint_arn with correct pattern
- [x] Configure target_endpoint_arn with correct pattern
- [x] Add environment and team tags

## Task 8: Validation
- [x] Run terraform validate
- [x] Run terraform plan to verify configuration
- [x] Verify all 20 table mapping rules are present
- [x] Confirm security group references work
