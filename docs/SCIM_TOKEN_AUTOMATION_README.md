# SCIM Token Automation

Automated generation and storage of Snowflake SCIM tokens for Okta provisioning.

## Overview

This automation eliminates manual SCIM token generation by:
- Checking existing token expiry date
- Only generating new tokens when within 45 days of expiry
- Connecting to Snowflake accounts using existing GitHub integration credentials
- Generating SCIM tokens using `SYSTEM$GENERATE_SCIM_ACCESS_TOKEN`
- Storing tokens securely in AWS Secrets Manager (per-account secrets)

**Smart Regeneration**: The script runs weekly but only generates new tokens when they're within 45 days of expiry, giving ample time to coordinate with the Okta team.

## Snowflake Accounts

SCIM tokens are **account-level** (not environment-level). Each Snowflake account has one token:

| Account | Nonprod Account ID | Prod Account ID |
|---------|-------------------|-----------------|
| exchange | QN78122 | ZZ82647 |
| group | DJ58410 | JV60414 |
| landinsights | WY17498 | US08173 |
| value-australia | HP89999 | VO84682 |

**Total: 8 tokens** (4 accounts × 2 env types)

## Quick Start

### Manual Execution

```bash
pip install -r requirements.txt

# Generate nonprod tokens (all accounts)
python utils/generate_scim_tokens.py --env-type nonprod

# Generate prod tokens (single account)
python utils/generate_scim_tokens.py --env-type prod --account exchange

# Dry run (no changes)
python utils/generate_scim_tokens.py --env-type nonprod --dry-run
```

### GitHub Actions

The workflow runs automatically every Monday (both nonprod and prod). To trigger manually:

1. Go to Actions → "Generate SCIM Tokens"
2. Select `env_type` (nonprod/prod)
3. Optionally select a specific account
4. Enable dry_run to test without changes
5. Click "Run workflow"

## Configuration

### Snowflake Accounts Config

`config/snowflake_accounts.json`:

```json
{
  "accounts": {
    "exchange": {
      "nonprod_account_identifier": "QN78122",
      "prod_account_identifier": "ZZ82647",
      "integration_name": "OKTA_PROVISIONING"
    }
  }
}
```

### AWS Secrets Manager

**SCIM Token Secrets** (per-account, per-env-type):
```
onedata/snowflake/{account}/{nonprod|prod}/scim-token
```

Example: `onedata/snowflake/exchange/nonprod/scim-token`

Structure:
```json
{
  "token": "token_value",
  "last_updated": "2026-01-22T00:00:00+00:00",
  "expires_at": "2026-07-22T00:00:00+00:00"
}
```

**Snowflake Credentials** (existing secrets):
```
onedata_{non-prod|prod}_{account}_snowflake-github-admin-user-private-key
onedata_{non-prod|prod}_{account}_snowflake-github-admin-user-passphrase
```

## Prerequisites

### Snowflake Permissions

The GitHub integration role must have permission to execute SCIM token generation:

```sql
-- For nonprod accounts
GRANT EXECUTE ON FUNCTION SYSTEM$GENERATE_SCIM_ACCESS_TOKEN TO ROLE DEV_GITHUB_INTEGRATION_ROLE_S;

-- For prod accounts  
GRANT EXECUTE ON FUNCTION SYSTEM$GENERATE_SCIM_ACCESS_TOKEN TO ROLE PRD_GITHUB_INTEGRATION_ROLE_S;
```

Verify with:
```sql
USE ROLE DEV_GITHUB_INTEGRATION_ROLE_S;
SELECT SYSTEM$GENERATE_SCIM_ACCESS_TOKEN('OKTA_PROVISIONING');
```

### AWS Permissions

GitHub Actions role (`GitHubRunnerPEXAOneDataRole`) needs:
- `secretsmanager:GetSecretValue` - read credentials and existing tokens
- `secretsmanager:PutSecretValue` - update token secrets
- `secretsmanager:CreateSecret` - create new token secrets

## Workflow Details

### Runners

| Environment | Runner | AWS Account |
|-------------|--------|-------------|
| nonprod | `[non-prod, deploy]` | NONPROD_PEXAONEDATA_AWS_ACCOUNT |
| prod | `[prod, deploy]` | PROD_PEXAONEDATA_AWS_ACCOUNT |

### Schedule

- **Weekly**: Every Monday at midnight UTC
- Both nonprod and prod jobs run on schedule
- Manual trigger runs only the selected env_type

## Token Lifecycle

- **Validity**: 6 months (180 days)
- **Check Frequency**: Weekly (every Monday)
- **Regeneration Threshold**: 45 days before expiry
- **Coordination Window**: 38-45 days for Okta team

### Timeline Example

```
Day 0:   Tokens generated (expires in 180 days)
Day 7:   Weekly check - skip (173 days remaining)
...
Day 133: Weekly check - skip (47 days remaining)
Day 140: Weekly check - GENERATE (40 days remaining)
Day 180: Old tokens expire
```

## Monitoring

### Check Token Expiry (nonprod example)

```bash
aws secretsmanager get-secret-value \
  --secret-id onedata/snowflake/exchange/nonprod/scim-token \
  --region ap-southeast-2 \
  --query 'SecretString' \
  --output text | jq '.expires_at'
```

### List All SCIM Token Secrets

```bash
aws secretsmanager list-secrets \
  --region ap-southeast-2 \
  --filter Key=name,Values=onedata/snowflake \
  --query 'SecretList[?contains(Name, `scim-token`)].Name'
```

## Troubleshooting

### Permission Denied

**Error**: `SQL access control error: Insufficient privileges`

**Solution**: Grant execute permission to the role:
```sql
GRANT EXECUTE ON FUNCTION SYSTEM$GENERATE_SCIM_ACCESS_TOKEN TO ROLE DEV_GITHUB_INTEGRATION_ROLE_S;
```

### Private Key Not Found

**Error**: `Private key not found: onedata_non-prod_exchange_snowflake-github-admin-user-private-key`

**Solution**: Verify the credential secret exists in the correct AWS account.

### Token Not Generated

**Error**: `No token returned`

**Solution**: Verify SCIM integration exists:
```sql
SHOW INTEGRATIONS LIKE 'OKTA_PROVISIONING';
```

## Support

- **Technical Issues**: Data Engineering Team
- **Access Issues**: Security Engineering (Ameena)
- **Repository**: pexa-one-data-snowflake-au-common-lib
