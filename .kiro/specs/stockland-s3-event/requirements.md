# Requirements Document

## Introduction

Add an S3 event notification configuration for the "stockland" prefix in the bespoke reporting S3 bucket (`onedata-bespokereporting-resources-s3.yml`). This enables the existing bespoke report Lambda function to automatically process files uploaded to the `stockland/` prefix, following the same pattern used for existing prefixes (anz/, cba/, westpac/, nab/).

## Glossary

- **Bespoke_Reporting_S3_Bucket**: The S3 bucket `pexa-onedata-egress-{AccountId}-{Environment}` used for bespoke report egress
- **Bespoke_Report_Lambda**: The Lambda function `onedata-bespoke-s3-extract-lambda-{Environment}` that processes uploaded report files
- **S3_Event_Notification**: An AWS S3 notification configuration that triggers a Lambda function when objects are created matching a specified prefix filter
- **Stockland_Prefix**: The S3 key prefix `stockland/` used to identify files belonging to the Stockland partner

## Requirements

### Requirement 1: Stockland S3 Event Notification

**User Story:** As a data engineer, I want S3 event notifications configured for the `stockland/` prefix, so that the bespoke report Lambda is automatically triggered when Stockland report files are uploaded to the egress bucket.

#### Acceptance Criteria

1. WHEN an object is created under the `stockland/` prefix in the Bespoke_Reporting_S3_Bucket, THE S3_Event_Notification SHALL invoke the Bespoke_Report_Lambda
2. THE S3_Event_Notification SHALL trigger on the `s3:ObjectCreated:*` event type for the `stockland/` prefix
3. THE S3_Event_Notification SHALL reference the Bespoke_Report_Lambda ARN via the existing CloudFormation cross-stack export `onedata-bespokereporting-resources-lambda-{Environment}:BespokeReportLambdaArn`
4. THE S3_Event_Notification SHALL use the same LambdaConfiguration structure as existing prefix notifications (anz/, cba/, westpac/, nab/)

### Requirement 2: Template Consistency

**User Story:** As a DevOps engineer, I want the Stockland notification to follow the same CloudFormation pattern as existing notifications, so that the infrastructure remains consistent and maintainable.

#### Acceptance Criteria

1. THE CloudFormation template SHALL define the Stockland notification as an additional entry in the `NotificationConfiguration.LambdaConfigurations` list
2. THE S3_Event_Notification filter SHALL use a `prefix` rule with the value `stockland/`
3. THE CloudFormation template SHALL remain deployable across all environments (dev, tst, pst, prf, prd) without additional parameters

### Requirement 3: Existing Functionality Preservation

**User Story:** As a data engineer, I want existing S3 event notifications to remain unchanged, so that current report processing for ANZ, CBA, Westpac, and NAB is not disrupted.

#### Acceptance Criteria

1. THE CloudFormation template SHALL retain all existing LambdaConfiguration entries for anz/, cba/, westpac/, and nab/ prefixes without modification
2. THE Bespoke_Reporting_S3_Bucket resource properties (encryption, lifecycle, access control) SHALL remain unchanged
