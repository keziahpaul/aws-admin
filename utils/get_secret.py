import boto3
import json
from botocore.exceptions import ClientError
import sys
import os


def get_secret(secret_name: str, key: str, flag, op_key: str = None):

    region_name = "ap-southeast-2"

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        raise e

    # Decrypts secret using the associated KMS key.
    secret = get_secret_value_response['SecretString']
    secrets_json = json.loads(secret, strict=False)
    if flag=="1":
        print(f"{op_key.upper()}=\"{secrets_json[key]}\"")
    else:
        print(secrets_json[key])


if __name__ == '__main__':
    get_secret(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])