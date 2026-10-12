# Versioning

## Overview

The Agent Platform Terraform module follows [Semantic Versioning 2.0.0](https://semver.org/):

```
MAJOR.MINOR.PATCH
```

| Part | When to increment |
|------|------------------|
| **MAJOR** | Breaking changes: variable renames, removed outputs, destructive resource replacements, module restructure that requires state moves |
| **MINOR** | Backward-compatible additions: new optional variables, new modules, new outputs, new optional features |
| **PATCH** | Backward-compatible fixes: bug fixes, security patches, documentation updates, non-destructive defaults changes |

## Git Tagging

Releases are tagged on `main` using annotated tags:

```bash
git tag -a v1.2.0 -m "Release v1.2.0: add agent-scheduler module"
git push origin v1.2.0
```

Module consumers pin to a release tag in their Terragrunt config:

```hcl
terraform {
  source = "git::https://github.com/pexa-au/pexa-one-data-aws-admin//terraform/infrastructure/agent-platform?ref=v1.2.0"
}
```

## Release Process

1. All changes merged to `develop` first via a feature branch PR.
2. Create a release branch: `release/v<MAJOR>.<MINOR>.<PATCH>`.
3. Bump version in `CHANGELOG.md` and update the `[Unreleased]` section.
4. Open PR from release branch -> `main`. Requires 1 approval.
5. After merge to `main`, tag the commit: `git tag -a v<version> -m "Release v<version>"`.
6. Push the tag: `git push origin v<version>`.
7. GitHub Actions (`deploy-agent-platform.yml`) deploys `pst` then `prd` automatically on `main`.

## Compatibility Matrix

| Module version | Terraform | AWS provider | Bedrock AgentCore provider |
|---------------|-----------|-------------|---------------------------|
| v1.x          | >= 1.6.0  | >= 5.0      | >= 1.0 (hashicorp/aws-preview) |

## Breaking Change Policy

- Breaking changes are only introduced in MAJOR releases.
- A migration guide is added to CHANGELOG.md describing any required `terraform state mv` operations or variable renames.
- At least one MINOR release with deprecation warnings precedes any breaking removal where possible.
