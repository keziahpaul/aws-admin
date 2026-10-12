import json
import urllib3
import boto3
from botocore.exceptions import ClientError
import sys

### This is a script to send a slack message to any channel and with any message 
### To use python3 scripts/send_slack_message.py "CHANNEL_ID" "MESSAGE"

# Initialize AWS clients
AWS_REGION = "ap-southeast-2"
secrets_manager = boto3.client('secretsmanager', region_name=AWS_REGION)

# Environment variables
slack_webhook_secret = "onedata-slack-app-bot-token"  # checkov:skip=CKV_SECRET_6:Not a secret, just a Secrets Manager path

def get_secret(secret_name):
    """Retrieve secret from AWS Secrets Manager"""
    try:
        response = secrets_manager.get_secret_value(SecretId=secret_name)
        if 'SecretString' in response:
            return json.loads(response['SecretString'])
        elif 'SecretBinary' in response:
            return json.loads(response['SecretBinary'].decode('utf-8'))
        else:
            raise KeyError(f"Neither 'SecretString' nor 'SecretBinary' found in secret {secret_name}")
    except ClientError as e:
        print(f"Error fetching secret {secret_name}: {e}", file=sys.stderr)
        raise

def get_slack_config():
    """Get Slack configuration from Secrets Manager"""
    try:
        secret = get_secret(slack_webhook_secret)
        return {
            'token': secret.get('token') or secret.get('bot_token')
        }
    except Exception as e:
        print(f"Failed to get Slack config: {e}", file=sys.stderr)
        return None

def send_slack_message(channel_id, message):
    """Send a message to a Slack channel"""
    config = get_slack_config()
    
    if not config or not config['token']:
        raise ValueError("Slack token not configured")

    payload = json.dumps({"channel": channel_id, "text": message})
    headers = {
        "Authorization": f"Bearer {config['token']}",
        "Content-Type": "application/json"
    }
    http = urllib3.PoolManager()
    response = http.request("POST", "https://slack.com/api/chat.postMessage", body=payload, headers=headers, timeout=30)
    return json.loads(response.data.decode('utf-8'))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 send_slack_message.py <CHANNEL_ID> <MESSAGE>", file=sys.stderr)
        sys.exit(1)
    channel_id = sys.argv[1]
    message = sys.argv[2]
    send_slack_message(channel_id, message)
    