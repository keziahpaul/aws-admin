# Implementation Plan: Stockland S3 Event Notification

## Overview

Add a new `LambdaConfigurations` entry for the `stockland/` prefix to the existing S3 bucket notification configuration in `onedata-bespokereporting-resources-s3.yml`. This is a single-file, additive change following the established pattern.

## Tasks

- [x] 1. Add Stockland S3 event notification to CloudFormation template
  - [x] 1.1 Append new LambdaConfigurations entry for stockland/ prefix
    - Open `cloudformation/templates/onedata-bespokereporting-resources/onedata-bespokereporting-resources-s3.yml`
    - Append a new entry to the `NotificationConfiguration.LambdaConfigurations` list after the existing `nab/` entry
    - Use identical structure: `Event: s3:ObjectCreated:*`, `Function` referencing `onedata-bespokereporting-resources-lambda-${Environment}:BespokeReportLambdaArn` via `ImportValue`, and `Filter` with `S3Key.Rules` prefix value `stockland/`
    - Ensure no existing entries (anz/, cba/, westpac/, nab/) are modified
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 3.1, 3.2_

  - [ ]* 1.2 Write property test: Stockland notification structural consistency (Property 1)
    - **Property 1: Stockland notification structural consistency**
    - Parse the modified YAML template and assert the `LambdaConfigurations` list contains an entry with `Event: s3:ObjectCreated:*`, filter prefix `stockland/`, and Lambda ARN resolved via the cross-stack export
    - Assert the stockland entry is structurally identical to the `anz/` entry (differing only in prefix value)
    - Use Python with PyYAML for template parsing
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 2.1, 2.2**

  - [ ]* 1.3 Write property test: No new parameters introduced (Property 2)
    - **Property 2: No new parameters introduced**
    - Parse the modified YAML template and assert the `Parameters` section contains exactly `Environment` and `Account` — no additions
    - **Validates: Requirements 2.3**

  - [ ]* 1.4 Write property test: Existing notifications preserved (Property 3)
    - **Property 3: Existing notifications preserved**
    - Parse the modified YAML template and assert all four original `LambdaConfigurations` entries (`anz/`, `cba/`, `westpac/`, `nab/`) remain present and unmodified
    - Assert non-notification properties of the `BespokeReportingS3` resource (BucketEncryption, LifecycleConfiguration, AccessControl, PublicAccessBlockConfiguration) are unchanged
    - **Validates: Requirements 3.1, 3.2**

- [ ] 2. Validate CloudFormation template
  - [ ] 2.1 Run YAML lint and CloudFormation template validation
    - Validate the modified template is syntactically correct YAML
    - Run `aws cloudformation validate-template --template-body file://cloudformation/templates/onedata-bespokereporting-resources/onedata-bespokereporting-resources-s3.yml` to confirm CloudFormation accepts the template
    - _Requirements: 2.1, 2.3_

- [ ] 3. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- This is a single-file additive change with zero impact on existing functionality
- The Lambda ARN is resolved via an existing cross-stack export — no new parameters or outputs needed
- Property tests use Python with PyYAML to parse and validate the CloudFormation template structure
