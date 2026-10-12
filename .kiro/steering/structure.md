# Project Structure

## File Organization
```
/cloudformation/          # CloudFormation templates and parameters
  /templates/            # Stack templates (.yml)
  /parameters/           # Environment-specific properties files
    /resources-{env}/    # Per-environment configs (dev, tst, pst, prf, prd)
/lambda/                 # Lambda function code
/terraform/              # Terraform/Terragrunt infrastructure
  /infrastructure/       # Infrastructure modules (privatelink, rds-dns-resolver)
/.github/
  /workflows/            # CI/CD pipeline definitions
  /actions/              # Reusable composite actions
  /config/               # Account configuration JSON files
```

## Naming Conventions
- **CloudFormation templates**: `{service}-{resource-type}.yml` (kebab-case)
- **Parameter files**: `{template-name}.properties`
- **Lambda functions**: `{purpose}_lambda.py` (snake_case)
- **Terraform files**: `main.tf`, `variables.tf`, `outputs.tf`
- **AWS Resources**: `{project}-{environment}-{resource-type}-{purpose}`
- **Variables/Functions**: snake_case (Python), PascalCase (CloudFormation)
- **Constants**: UPPER_SNAKE_CASE

## Import Patterns
- **Python**: Standard library → third-party → local imports
- **Terraform**: Use versioned Git references for modules
- **CloudFormation**: SAM Transform for serverless resources

## Architectural Decisions
- **Multi-Account Strategy**: Separate accounts for Data, Core, Digital, Management
- **Event-Driven Processing**: S3 triggers Lambda for report automation
- **Infrastructure as Code**: CloudFormation primary, Terraform for complex modules
- **Cross-Account Access**: IAM role assumption pattern
- **Secrets Management**: AWS Secrets Manager only, no hardcoded values

## Code Organization
- **Lambda Logic**: Single-file functions in `/lambda/`
- **Infrastructure Modules**: Separated by service type in `/terraform/infrastructure/`
- **Deployment Configs**: Environment-specific `.properties` files
- **Reusable Workflows**: Parameterized GitHub Actions for multi-account deployment
- **Account Configs**: JSON files in `.github/config/` for account mappings

## GitHub Actions Workflow Patterns

### CRITICAL: Never use matrix strategy for multi-environment deployments
GitHub environment protection rules cancel the entire matrix when one leg fails. Always use separate jobs per environment.

### Caller + Reusable Workflow Pattern
This is the standard pattern used across the repo (privatelink, rds-dns-resolver, data-ingestion):

**Caller workflow** (`deploy-*.yml`):
- Defines explicit jobs per environment: dev, tst, pst, prd
- Each job has `if:` conditions for branch protection:
  - `dev` → `feature/*` branches only
  - `tst` → `develop` branch only
  - `pst`/`prd` → `main` or `release/*` branches only
- `prd` always `needs: [pst]` (deploy pst before prd)
- Resolves account config (account ID, runner type) in a validate job
- Passes `terragrunt-path`, `aws-account`, `environment`, `runner-type` to the reusable workflow

**Reusable workflow** (`reusable-*.yml`):
- Generic single-job workflow — no environment awareness or branch logic
- Accepts `terragrunt-path` as input and uses it as `working-directory`
- Runs: checkout → AWS creds → init → validate → plan → apply → cleanup
- Any extra steps (e.g., S3 sync for Lambda) are added after apply

### Key Rules
- Branch protection logic belongs in the **caller**, not the reusable workflow
- Reusable workflows must be generic — operate on whatever `terragrunt-path` they receive
- Never use dynamic environment parsing or matrix — hardcode per-env jobs
- Follow existing patterns (e.g., `onedata-bespokereporting-resources-s3-deploy.yml`) — don't invent new ones

## Code Style Rules
- Prefer `csv.DictReader` over `csv.reader` + manual index tracking when column names are known
- Use built-in library features (e.g., `csv_reader.line_num`) instead of manual counters
- Prefer dict-based lookups over positional `zip`/`enumerate` when mapping names to values
- Avoid nested `enumerate`/`zip` constructs — flatten with named dict access for readability

## Code Refactoring Rules
- Never remove defensive checks (file existence, null checks, safe navigation operators) when refactoring
- When simplifying code, preserve all validation and error handling from the original
- If a check exists in the original code, assume it's there for a reason — keep it unless explicitly told to remove it

## Git Branching Rules
- Always create PRs against `develop`, never against `main`
- Feature branches follow the naming convention: `feature/DD-{ticket}-{description}`
