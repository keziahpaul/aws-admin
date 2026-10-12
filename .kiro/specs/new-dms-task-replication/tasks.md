# Implementation Plan: New DMS Task Replication

## Overview

This implementation plan creates a new AWS DMS serverless replication task that reuses existing endpoints from the onedata-exchange-resources-core-DMS-components stack. The implementation follows the established CloudFormation patterns and directory structure while providing flexibility for different table mappings and replication scenarios.

## Tasks

- [x] 1. Create CloudFormation template structure and parameters
  - Create the new CloudFormation template file following naming conventions
  - Define all required parameters (Environment, MinDCU, MaxDCU, TaskIdentifier)
  - Set up template metadata and description
  - _Requirements: 5.1, 5.2, 5.5_

- [ ]* 1.1 Write property test for template structure validation
  - **Property 9: CloudFormation template structure validation**
  - **Validates: Requirements 5.1, 5.2, 5.4**

- [ ] 2. Implement DMS ReplicationConfig resource
  - [x] 2.1 Configure compute settings with DCU parameters
    - Set up ComputeConfig with MultiAZ, MinCapacityUnits, MaxCapacityUnits
    - Configure PreferredMaintenanceWindow and networking references
    - _Requirements: 3.1, 3.2, 3.3, 3.4_
  
  - [ ]* 2.2 Write property test for compute configuration
    - **Property 5: Compute configuration validation**
    - **Validates: Requirements 3.1, 3.2, 3.3**
  
  - [x] 2.3 Configure replication settings and type
    - Set ReplicationType to "full-load-and-cdc"
    - Configure ReplicationSettings with logging, target metadata, and full load settings
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  
  - [ ]* 2.4 Write property test for replication settings
    - **Property 8: Replication type and settings validation**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5**

- [ ] 3. Configure endpoint references and cross-stack integration
  - [x] 3.1 Set up source and target endpoint ARN references
    - Configure SourceEndpointArn and TargetEndpointArn using existing endpoints
    - Implement proper ARN format for cross-stack integration
    - _Requirements: 1.1, 1.2, 1.5_
  
  - [ ]* 3.2 Write property test for endpoint ARN references
    - **Property 1: Endpoint ARN references validation**
    - **Validates: Requirements 1.1, 1.2, 1.5**
  
  - [x] 3.3 Configure networking and security group references
    - Set up VpcSecurityGroupIds using cross-stack imports
    - Configure ReplicationSubnetGroupId reference
    - _Requirements: 3.4, 6.3_
  
  - [ ]* 3.4 Write property test for network configuration
    - **Property 6: Network configuration references validation**
    - **Validates: Requirements 3.4**

- [ ] 4. Implement table mappings configuration
  - [x] 4.1 Create selection rules for specified tables
    - Define selection rules for all tables from the table structure list
    - Configure proper schema-name and table-name for each rule
    - _Requirements: 2.1, 2.5_
  
  - [ ]* 4.2 Write property test for table mapping structure
    - **Property 2: Table mapping structure validation**
    - **Validates: Requirements 2.1, 2.4, 2.5**
  
  - [x] 4.3 Add transformation rules for transaction sequence columns
    - Implement transformation rules to add transact_id columns
    - Configure proper data types and expressions for transformations
    - _Requirements: 2.2_
  
  - [ ]* 4.4 Write property test for transformation rules
    - **Property 3: Transformation rules validation**
    - **Validates: Requirements 2.2**
  
  - [x] 4.5 Configure parallel loading settings for partitioned tables
    - Add table-settings rules for tables with partitions > 0
    - Configure range-based boundaries for parallel loading
    - _Requirements: 2.3_
  
  - [ ]* 4.6 Write property test for parallel loading configuration
    - **Property 4: Parallel loading configuration validation**
    - **Validates: Requirements 2.3**

- [x] 5. Checkpoint - Validate template structure and configuration
  - Ensure all template sections are complete and syntactically correct
  - Verify all cross-stack references are properly formatted
  - Ask the user if questions arise

- [ ] 6. Configure security and encryption settings
  - [x] 6.1 Set up KMS encryption configuration
    - Configure KmsKeyId for compute config when encryption is required
    - Ensure S3 target encryption settings reference existing KMS keys
    - _Requirements: 3.5, 6.2_
  
  - [ ]* 6.2 Write property test for encryption configuration
    - **Property 7: Encryption configuration validation**
    - **Validates: Requirements 3.5, 6.2**
  
  - [x] 6.3 Validate security compliance settings
    - Ensure IAM role references are correct for existing roles
    - Verify Secrets Manager integration for database credentials
    - Confirm SSL encryption settings for database connections
    - _Requirements: 6.1, 6.4, 6.5_
  
  - [ ]* 6.4 Write property test for security configuration
    - **Property 11: Security configuration compliance validation**
    - **Validates: Requirements 6.1, 6.3, 6.4, 6.5**

- [ ] 7. Configure S3 target settings validation
  - [x] 7.1 Validate S3 target endpoint configuration
    - Verify CSV format with pipe delimiters and proper row delimiters
    - Confirm GZIP compression and column name settings
    - Ensure timestamp columns and folder structure configuration
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_
  
  - [ ]* 7.2 Write property test for S3 configuration
    - **Property 12: S3 target configuration validation**
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5**

- [ ] 8. Add resource tagging and outputs
  - [x] 8.1 Configure resource tags
    - Add environment and team tags to all resources
    - Follow established tagging patterns from existing templates
    - _Requirements: 5.3_
  
  - [x] 8.2 Define template outputs
    - Export ReplicationConfig ARN for potential cross-stack references
    - Follow established output naming conventions
    - _Requirements: 5.4_
  
  - [ ]* 8.3 Write property test for tagging and naming
    - **Property 10: Resource tagging and naming validation**
    - **Validates: Requirements 5.3, 5.5**

- [ ] 9. Create parameter files for all environments
  - [x] 9.1 Create development environment parameters
    - Set appropriate DCU values for development workloads
    - Configure environment-specific identifiers
    - _Requirements: 5.2_
  
  - [x] 9.2 Create test environment parameters
    - Configure parameters for testing scenarios
    - Set appropriate resource sizing for test workloads
    - _Requirements: 5.2_
  
  - [x] 9.3 Create production environment parameters
    - Configure production-appropriate DCU values
    - Set production-specific identifiers and settings
    - _Requirements: 5.2_

- [ ] 10. Final validation and integration testing
  - [x] 10.1 Validate template syntax and structure
    - Run CloudFormation template validation
    - Verify all parameter references are correct
    - _Requirements: 5.1_
  
  - [ ]* 10.2 Write integration tests for cross-stack references
    - Test endpoint ARN resolution in isolated environment
    - Validate security group and subnet group references
    - _Requirements: 1.1, 1.2, 3.4_
  
  - [x] 10.3 Create deployment documentation
    - Document deployment steps and prerequisites
    - Include troubleshooting guide for common issues
    - _Requirements: 5.1_

- [x] 11. Final checkpoint - Ensure all tests pass
  - Ensure all property tests and integration tests pass
  - Verify template can be deployed successfully in development environment
  - Ask the user if questions arise

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Integration tests validate cross-stack functionality
- The implementation follows established CloudFormation patterns and AWS best practices