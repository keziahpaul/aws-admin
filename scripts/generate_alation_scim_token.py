import json
import sys
import boto3
from botocore.exceptions import ClientError
import requests
from datetime import datetime, timezone
from dateutil import parser as dateutil_parser
import re
import os

# ---------- Config ----------
AWS_REGION = "ap-southeast-2"
DEFAULT_SECRET_PREFIX = "onedata/Alation"  # checkov:skip=CKV_SECRET_6:Not a secret, just a path prefix
# ----------------------------

_secrets_client = None

def get_secrets_client():
    global _secrets_client
    if _secrets_client is None:
        _secrets_client = boto3.client("secretsmanager", region_name=AWS_REGION)
    return _secrets_client


def get_secret(secret_name: str) -> dict:
    client = get_secrets_client()
    try:
        response = client.get_secret_value(SecretId=secret_name)
    except ClientError as e:
        error_code = e.response["Error"]["Code"]
        raise ClientError(
            e.response,
            f"Failed to retrieve secret '{secret_name}': {error_code}"
        ) from e

    secret = json.loads(response["SecretString"])
    return secret


def get_credentials_secret_name() -> str:
    return f"{DEFAULT_SECRET_PREFIX}/OAuth_Client_Application"


def create_jwt_token(client_id: str, client_secret: str) -> dict:
    url = "https://onedd-pexa.ap.alationcloud.com/oauth/v2/token"
    payload = {
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_secret": client_secret
    }
    headers = {
        "accept": "application/json",
        "content-type": "application/x-www-form-urlencoded"
    }

    response = requests.post(url, data=payload, headers=headers, timeout=30)
    response.raise_for_status()
    data = response.json()

    if "access_token" not in data:
        raise ValueError(f"JWT token response missing 'access_token': {data}")

    return data


def verify_jwt_token(client_id: str, client_secret: str, jwt_token: str) -> dict:
    url = "https://onedd-pexa.ap.alationcloud.com/oauth/v2/introspect"
    payload = {
        "token_type_hint": "access_token",
        "client_id": client_id,
        "client_secret": client_secret,
        "token": jwt_token
    }
    headers = {
        "accept": "application/json",
        "content-type": "application/x-www-form-urlencoded"
    }

    response = requests.post(url, data=payload, headers=headers, timeout=30)
    response.raise_for_status()
    data = response.json()

    if "active" not in data:
        raise ValueError(f"JWT introspect response missing 'active' field: {data}")

    return data


def generate_scim_token(jwt_token: str) -> dict:
    url = "https://onedd-pexa.ap.alationcloud.com/scim/v2/token/"
    headers = {
        "accept": "application/json",
        "content-type": "application/json",
        "TOKEN": jwt_token
    }

    response = requests.post(url, headers=headers, timeout=30)
    response.raise_for_status()
    data = response.json()

    if "token" not in data or "expires_in" not in data:
        raise ValueError(f"SCIM token response missing expected fields: {data}")

    return data


def put_secret(secret_name: str, secret_value: dict) -> None:
    client = get_secrets_client()
    try:
        client.put_secret_value(SecretId=secret_name, SecretString=json.dumps(secret_value))
    except client.exceptions.ResourceNotFoundException:
        client.create_secret(Name=secret_name, SecretString=json.dumps(secret_value))
    except ClientError as e:
        error_code = e.response["Error"]["Code"]
        raise ClientError(
            e.response,
            f"Failed to store secret '{secret_name}': {error_code}"
        ) from e

def check_expiry(expires_in: str) -> bool:
    """Check if the current date is within 45 days of the token expiry date."""
    # Remove ordinal suffixes (st, nd, rd, th) for parsing
    cleaned = re.sub(r'(\d+)(st|nd|rd|th)', r'\1', expires_in)
    expiry_date = dateutil_parser.parse(cleaned, default=datetime(1970, 1, 1, tzinfo=timezone.utc))
    days_until_expiry = (expiry_date - datetime.now(timezone.utc)).days
    return days_until_expiry <= 45

if __name__ == "__main__":

    scim_secret_name = f"{DEFAULT_SECRET_PREFIX}/SCIM_token"

    try:
        scim_value = get_secret(scim_secret_name)
        token_needs_refresh = check_expiry(scim_value['expires_at'])
    except ClientError as e:
        if e.response["Error"]["Code"] == "ResourceNotFoundException":
            token_needs_refresh = True
        else:
            raise
    if token_needs_refresh:

        credentials_secret_name = get_credentials_secret_name()
        credentials = get_secret(credentials_secret_name)

        jwt_token_data = create_jwt_token(credentials['Client_ID'], credentials['Client_Secret'])

        jwt_status = verify_jwt_token(credentials['Client_ID'], credentials['Client_Secret'], jwt_token_data['access_token'])

        if jwt_status['active']:
            print("JWT access token is active")
            scim_payload = generate_scim_token(jwt_token_data['access_token'])

            now = datetime.now(timezone.utc).replace(microsecond=0)

            payload = {
                "token": scim_payload['token'],
                "last_updated": now.isoformat(),
                "expires_at": scim_payload['expires_in']
            }

            put_secret(scim_secret_name, payload)
            print(f"SCIM token stored at: {scim_secret_name}")

            # Set GitHub Actions output to indicate token was generated
            gh_output = os.environ.get("GITHUB_OUTPUT")
            if gh_output:
                with open(gh_output, "a") as f:
                    f.write("token_generated=true\n")
        else:
            print("JWT access token inactive")
            sys.exit(1)
    else:
        print("Token still valid for longer than 45 days")

