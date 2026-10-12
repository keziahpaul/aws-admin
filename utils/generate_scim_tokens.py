#!/usr/bin/env python3
"""
SCIM token generator for Snowflake accounts.

Generates account-level SCIM tokens (one per nonprod/prod account) and stores in AWS Secrets Manager.
"""

import argparse
import json
import logging
import os
import re
import time
from datetime import datetime, timedelta, timezone
from functools import wraps
from typing import Optional

import boto3
import snowflake.connector
from botocore.exceptions import ClientError
from cryptography.hazmat.primitives import serialization

# ---------- Config ----------
AWS_REGION = "ap-southeast-2"
DEFAULT_SECRET_PREFIX = "onedata/snowflake"  # checkov:skip=CKV_SECRET_6:Not a secret, just a path prefix
TOKEN_VALIDITY_DAYS = 180
REGENERATE_THRESHOLD_DAYS = 45
MAX_RETRIES = 3
RETRY_BACKOFF = 2
VALID_IDENTIFIER_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
# ----------------------------

logger = logging.getLogger("scim-rotator")
handler = logging.StreamHandler()
formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(logging.INFO)

# Cache secrets client
_secrets_client = None


def get_secrets_client():
    global _secrets_client
    if _secrets_client is None:
        _secrets_client = boto3.client("secretsmanager", region_name=AWS_REGION)
    return _secrets_client


def retry_on_exception(max_attempts=MAX_RETRIES, backoff=RETRY_BACKOFF, exceptions=(ClientError,)):
    def deco(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    if attempt + 1 >= max_attempts:
                        raise
                    sleep_seconds = backoff * (2 ** attempt)
                    logger.warning("Retry %d/%d for %s: %s", attempt + 1, max_attempts, func.__name__, e)
                    time.sleep(sleep_seconds)
        return wrapper
    return deco


def load_account_config(config_path: Optional[str] = None) -> dict:
    if config_path is None:
        config_path = os.path.join(os.path.dirname(__file__), "..", "config", "snowflake_accounts.json")
    with open(config_path, "r") as f:
        return json.load(f)


@retry_on_exception()
def get_secret_string(secret_name: str) -> Optional[str]:
    """Get raw secret string."""
    client = get_secrets_client()
    try:
        resp = client.get_secret_value(SecretId=secret_name)
        return resp.get("SecretString") or resp["SecretBinary"].decode("utf-8")
    except client.exceptions.ResourceNotFoundException:
        return None


def get_secret(secret_name: str) -> Optional[dict]:
    """Get secret as parsed JSON dict."""
    secret_str = get_secret_string(secret_name)
    return json.loads(secret_str) if secret_str else None


@retry_on_exception()
def put_secret(secret_name: str, secret_value: dict) -> None:
    client = get_secrets_client()
    try:
        client.put_secret_value(SecretId=secret_name, SecretString=json.dumps(secret_value))
    except client.exceptions.ResourceNotFoundException:
        client.create_secret(Name=secret_name, SecretString=json.dumps(secret_value))


def get_credential_secret_names(account: str, env_type: str) -> dict:
    """
    Secret names: onedata_{nonprod|prod}_{account}_snowflake-github-admin-user-private-key
    """
    deploy_env = "prod" if env_type == "prod" else "nonprod"
    return {
        "private_key": f"onedata_{deploy_env}_{account}_snowflake-github-admin-user-private-key",
        "passphrase": f"onedata_{deploy_env}_{account}_snowflake-github-admin-user-passphrase",
    }


def get_scim_token_secret_name(account: str, env_type: str) -> str:
    """SCIM token secret: onedata/snowflake/{account}/{nonprod|prod}/scim-token"""
    return f"{DEFAULT_SECRET_PREFIX}/{account}/{env_type}/scim-token"


def load_private_key_der(pem_text: str, passphrase: Optional[str] = None) -> bytes:
    pem_bytes = pem_text.encode("utf-8") if isinstance(pem_text, str) else pem_text
    password = passphrase.encode("utf-8") if passphrase else None
    private_key = serialization.load_pem_private_key(pem_bytes, password=password)
    return private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


def connect_to_snowflake(account_id: str, user: str, private_key_der: bytes, role: str):
    return snowflake.connector.connect(
        user=user,
        account=account_id,
        private_key=private_key_der,
        role=role,
        client_session_keep_alive=False,
    )


def generate_scim_token(connection, integration_name: str) -> Optional[str]:
    if not VALID_IDENTIFIER_PATTERN.match(integration_name):
        raise ValueError(f"Invalid integration name: {integration_name}")
    cursor = connection.cursor()
    try:
        cursor.execute("SELECT SYSTEM$GENERATE_SCIM_ACCESS_TOKEN(%s)", (integration_name,))
        result = cursor.fetchone()
        return result[0] if result else None
    finally:
        cursor.close()


def should_regenerate(secret_value: Optional[dict], threshold_days: int) -> bool:
    if not secret_value or not secret_value.get("expires_at"):
        return True
    try:
        expires_dt = datetime.fromisoformat(secret_value["expires_at"])
        if expires_dt.tzinfo is None:
            expires_dt = expires_dt.replace(tzinfo=timezone.utc)
        days_left = (expires_dt - datetime.now(timezone.utc)).days
        logger.info("Token expires in %d days", days_left)
        return days_left <= threshold_days
    except Exception:
        return True


def process_account(acc_name: str, account: dict, env_type: str, threshold_days: int, dry_run: bool) -> dict:
    """
    env_type: 'nonprod' or 'prod'
    """
    account_id = account[f"{env_type}_account_identifier"]
    integration_name = account.get("integration_name", "OKTA_PROVISIONING")
    
    # Use GITHUB_INTEGRATION_ADMIN_USER with ACCOUNTADMIN role for org-wide operations
    user = "GITHUB_INTEGRATION_ADMIN_USER"
    role = "ACCOUNTADMIN"
    
    logger.info("Processing %s %s (account=%s)%s", acc_name, env_type, account_id, " [DRY-RUN]" if dry_run else "")
    
    token_secret_name = get_scim_token_secret_name(acc_name, env_type)
    existing = get_secret(token_secret_name)
    
    if not should_regenerate(existing, threshold_days):
        logger.info("Skipping %s %s - token not due for regeneration", acc_name, env_type)
        return {"account": acc_name, "env": env_type, "status": "skipped"}
    
    cred_secrets = get_credential_secret_names(acc_name, env_type)
    private_key_pem = get_secret_string(cred_secrets["private_key"])
    passphrase = get_secret_string(cred_secrets["passphrase"])
    
    if not private_key_pem:
        return {"account": acc_name, "env": env_type, "status": "error", "error": f"Private key not found: {cred_secrets['private_key']}"}
    
    connection = None
    try:
        private_key_der = load_private_key_der(private_key_pem, passphrase)
        connection = connect_to_snowflake(account_id, user, private_key_der, role)
        
        token = generate_scim_token(connection, integration_name)
        if not token:
            raise Exception("No token returned from Snowflake")
        
        now = datetime.now(timezone.utc).replace(microsecond=0)
        payload = {
            "token": token,
            "last_updated": now.isoformat(),
            "expires_at": (now + timedelta(days=TOKEN_VALIDITY_DAYS)).isoformat(),
        }
        
        if dry_run:
            logger.info("[DRY-RUN] Would update %s", token_secret_name)
            return {"account": acc_name, "env": env_type, "status": "ok (dry-run)"}
        
        put_secret(token_secret_name, payload)
        logger.info("Updated secret %s", token_secret_name)
        return {"account": acc_name, "env": env_type, "status": "ok"}
        
    except Exception as e:
        logger.exception("Failed %s %s: %s", acc_name, env_type, e)
        return {"account": acc_name, "env": env_type, "status": "error", "error": str(e)}
    finally:
        if connection:
            connection.close()


def parse_args():
    p = argparse.ArgumentParser(description="SCIM token rotator for Snowflake")
    p.add_argument("--config", help="Account config path")
    p.add_argument("--env-type", "-e", default="nonprod", choices=["nonprod", "prod"], help="nonprod or prod")
    p.add_argument("--account", help="Process single account")
    p.add_argument("--dry-run", action="store_true", help="Simulate without writing")
    p.add_argument("--threshold-days", type=int, default=REGENERATE_THRESHOLD_DAYS)
    return p.parse_args()


def job_result(status: str, accounts_regenerated: str = None, error_details: str = None) -> dict:
    result = {"generate_status": status}
    if accounts_regenerated:
        result["accounts_regenerated"] = accounts_regenerated
    if error_details:
        result["error_details"] = error_details
    return result


def main() -> dict:
    args = parse_args()
    config = load_account_config(args.config)
    accounts = config.get("accounts", {})
    
    if args.account:
        if args.account not in accounts:
            logger.error("Account %s not found", args.account)
            return job_result("failed", error_details=f"Account {args.account} not found")
        accounts = {args.account: accounts[args.account]}
    
    results = []
    for acc_name, acc in accounts.items():
        res = process_account(acc_name, acc, args.env_type, args.threshold_days, args.dry_run)
        results.append(res)
    
    ok = [r for r in results if r["status"].startswith("ok")]
    skipped = [r for r in results if r["status"] == "skipped"]
    errors = [r for r in results if r["status"] == "error"]
    
    logger.info("Summary: %d ok, %d skipped, %d errors", len(ok), len(skipped), len(errors))

    if errors:
        for e in errors:
            logger.error("%s %s: %s", e["account"], e["env"], e.get("error"))
        error_details = "; ".join(f"{e['account']}: {e.get('error', 'unknown')}" for e in errors)
        return job_result("failed", error_details=error_details)
    elif ok:
        accounts_regenerated = ",".join(r["account"] for r in ok)
        return job_result("tokens-generated", accounts_regenerated=accounts_regenerated)
    else:
        return job_result("no-changes")


if __name__ == "__main__":
    try:
        result = main()
    except Exception as e:
        logger.exception("Fatal error: %s", e)
        result = job_result("failed", error_details=str(e))
    print(json.dumps(result))
