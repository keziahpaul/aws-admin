# Requirements Document

## Introduction

This feature adds a new AWS DMS (Database Migration Service) serverless replication task that reuses existing source and target endpoints from the current DMS infrastructure. The new task will enable replication of specific tables for Data Analytics Infrastructure (DAI) while leveraging the established endpoint configurations, security groups, and IAM roles.

## Glossary

- **DMS_Task**: AWS DMS ReplicationConfig resource that performs database replication
- **Source_Endpoint**: AWS DMS endpoint pointing to the source database (Aurora PostgreSQL)
- **Target_Endpoint**: AWS DMS endpoint pointing to the target storage (S3 bucket)
- **Table_Mappings**: Configuration defining which tables to replicate and any transformations
- **Replication_Config**: The complete DMS serverless task configuration including compute, networking, and data settings
- **CDC**: Change Data Capture - ongoing replication of database changes
- **Full_Load**: Initial complete copy of selected tables

## Requirements

### Requirement 1

**User Story:** As a data engineer, I want to create a new DMS replication task using existing endpoints, so that I can replicate additional data without creating new infrastructure components.

#### Acceptance Criteria

1. WHEN the new DMS task is deployed, THE Replication_Config SHALL use the existing Source_Endpoint from the onedata-exchange-resources-core-DMS-components stack
2. WHEN the new DMS task is deployed, THE Replication_Config SHALL use the existing Target_Endpoint from the onedata-exchange-resources-core-DMS-components stack
3. WHEN the new DMS task is created, THE Replication_Config SHALL have the identifier "onedata-exchange-resources-core-DMS-load" with environment prefix
4. THE Replication_Config SHALL be deployed as a separate CloudFormation template to enable independent lifecycle management
5. WHEN the task is configured, THE Replication_Config SHALL reference endpoints using cross-stack imports from the DMS components stack

### Requirement 2

**User Story:** As a data engineer, I want to configure table mappings for the new DMS task, so that I can specify which tables to replicate and apply necessary transformations.

#### Acceptance Criteria

1. WHEN table mappings are defined, THE Table_Mappings SHALL include selection rules for 14 specific tables from the source database
2. THE Table_Mappings SHALL NOT include transformation rules as they are not required for this implementation
3. WHEN large tables are included, THE Table_Mappings SHALL support parallel loading configuration with range-based boundaries
4. THE Table_Mappings SHALL follow the same rule structure as existing DMS tasks for consistency
5. WHEN tables are selected, THE Table_Mappings SHALL specify the correct schema name and table name for each selection rule

### Requirement 3

**User Story:** As a data engineer, I want to configure compute resources for the new DMS task, so that I can ensure adequate performance while managing costs.

#### Acceptance Criteria

1. THE Replication_Config SHALL support configurable MinDCU and MaxDCU parameters without default values or constraints
2. WHEN compute is configured, THE Replication_Config SHALL use Multi-AZ deployment for high availability
3. THE Replication_Config SHALL include a maintenance window configuration to minimize impact on operations
4. WHEN networking is configured, THE Replication_Config SHALL use the existing DMS subnet group and security group
5. THE Replication_Config SHALL NOT include KMS encryption configuration at the compute level

### Requirement 4

**User Story:** As a data engineer, I want the new DMS task to support full load and CDC replication, so that I can perform initial data migration and ongoing synchronization.

#### Acceptance Criteria

1. THE Replication_Config SHALL be configured with "full-load-and-cdc" replication type
2. WHEN full load is performed, THE Replication_Config SHALL support configurable MaxFullLoadSubTasks for parallel processing
3. WHEN target preparation is configured, THE Replication_Config SHALL use "DO_NOTHING" target table preparation mode
4. THE Replication_Config SHALL include logging configuration with EnableLogging set to true
5. WHEN LOB data is encountered, THE Replication_Config SHALL handle LOB data with configurable maximum size limits

### Requirement 5

**User Story:** As a DevOps engineer, I want the new DMS task to follow infrastructure as code practices, so that I can deploy and manage it consistently across environments.

#### Acceptance Criteria

1. THE DMS_Task SHALL be defined in a CloudFormation template named "onedata-exchange-resources-core-DMS-task.yml"
2. WHEN the template is deployed, THE DMS_Task SHALL accept environment-specific parameters without default values or constraints
3. THE DMS_Task SHALL include proper resource tagging for environment identification and team ownership
4. WHEN outputs are defined, THE DMS_Task SHALL export the replication config ARN for potential cross-stack references
5. THE DMS_Task SHALL follow the existing naming conventions and directory structure patterns

### Requirement 6

**User Story:** As a security engineer, I want the new DMS task to maintain security compliance, so that data replication follows established security standards.

#### Acceptance Criteria

1. WHEN the DMS task accesses the source database, THE Replication_Config SHALL use the existing IAM role with appropriate permissions
2. WHEN the DMS task writes to S3, THE Replication_Config SHALL use KMS encryption configured at the S3 target endpoint level
3. THE Replication_Config SHALL operate within the existing VPC security group constraints
4. WHEN secrets are accessed, THE Replication_Config SHALL use AWS Secrets Manager for database credentials
5. THE Replication_Config SHALL maintain SSL/TLS encryption for database connections

### Requirement 7

**User Story:** As a data engineer, I want to configure S3 target settings for the new DMS task, so that replicated data is stored in the appropriate format and location.

#### Acceptance Criteria

1. WHEN data is written to S3, THE Target_Endpoint SHALL use CSV format with pipe delimiter and proper row delimiters
2. THE Target_Endpoint SHALL enable GZIP compression for storage efficiency
3. WHEN files are created, THE Target_Endpoint SHALL include column names and operation indicators for full load
4. THE Target_Endpoint SHALL add timestamp columns for extraction tracking
5. WHEN data is stored, THE Target_Endpoint SHALL organize files in the designated bucket folder structure