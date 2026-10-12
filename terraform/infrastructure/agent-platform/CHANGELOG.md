# Changelog

All notable changes to the Agent Platform Terraform module will be documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project follows [Semantic Versioning](VERSIONING.md).

---

## [Unreleased]

### Added
- Nothing yet.

---

## [1.0.0] - 2026-08-14

Initial release of the Agent Platform Terraform module.

### Added

#### Infrastructure
- Composition root (`main.tf`) wiring all modules via `for_each` on the `agents` list
- Shared OpenSearch Serverless VECTORSEARCH collection (conditional on `create_opensearch_collection`)
- Per-environment Terragrunt configurations for `datanp/dev`, `datanp/tst`, `dataprd/pst`, `dataprd/prd`
- PIA agent tfvars for all four environments

#### Modules
- `iam` - ECS task execution role, ECS task role, optional Bedrock KB service role
- `s3-kb-bucket` - Private encrypted S3 bucket for KB data source
- `secrets` - Secrets Manager secrets (created + existing ARN references)
- `agent-runtime` - Bedrock AgentCore runtime, ECR repository, security group, CloudWatch log group
- `ecs-service` - ECS Fargate service for the Slack bot, optional ECR repository
- `bedrock-kb` - Bedrock Knowledge Base backed by OpenSearch Serverless
- `agent-memory` - AgentCore memory store with configurable strategies and expiry
- `agent-gateway` - AgentCore MCP gateway with IAM authorizer
- `agent-scheduler` - EventBridge Scheduler + Lambda trigger for scheduled runtime invocations
- `observability` - CloudWatch dashboard, error rate / latency / ECS task count alarms, SNS topic

#### Variables
- `agents` list with full feature-flag schema (enable_kb, enable_memory, enable_gateway, enable_slack_bot, enable_scheduler)
- `use_fargate_spot` for cost-optimized non-production ECS deployments
- `create_opensearch_collection` to control shared collection lifecycle

#### CI/CD
- `reusable-agent-platform-deploy.yml` - reusable Terragrunt deploy workflow (checkout, OIDC auth, init, validate, plan, apply)
- `deploy-agent-platform.yml` - caller workflow with explicit per-env jobs (dev, tst, pst, prd), no matrix strategy
- `agent-platform-accounts.json` - account and environment mapping for the CI/CD pipeline

#### Documentation
- README for each module (variables, outputs, usage example)
- Top-level `README.md` for the composition root
- `VERSIONING.md` - versioning and release process
- `CHANGELOG.md` - this file
- `scripts/validate-all.sh` - local HCL format and validate script

---

<!-- Link references -->
[Unreleased]: https://github.com/pexa-au/pexa-one-data-aws-admin/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/pexa-au/pexa-one-data-aws-admin/releases/tag/v1.0.0
