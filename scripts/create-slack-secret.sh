#!/bin/bash
# Script to create/update Slack bot token secret in AWS Secrets Manager
# Usage: ./create-slack-secret.sh <bot-token> [channel-id]

if [ -z "$1" ]; then
  echo "Usage: $0 <bot-token> [channel-id]"
  echo "Example: $0 xoxb-your-bot-token-here C0AD2GYJ9SN"
  exit 1
fi

BOT_TOKEN="$1"
CHANNEL_ID="${2:-C0AD2GYJ9SN}"
SECRET_NAME="onedata-slack-app-bot-token"
REGION="ap-southeast-2"

# Create secret JSON - compatible with Lambda's get_slack_config()
SECRET_VALUE=$(cat <<EOF
{
  "token": "${BOT_TOKEN}",
  "channels": {
    "empower": "${CHANNEL_ID}",
    "default": "${CHANNEL_ID}"
  }
}
EOF
)

# Try to create the secret
echo "Creating secret ${SECRET_NAME}..."
aws secretsmanager create-secret \
  --name "${SECRET_NAME}" \
  --description "Slack bot token for OneData app - data ingestion notifications" \
  --secret-string "${SECRET_VALUE}" \
  --region "${REGION}" 2>/dev/null

# If creation fails (secret exists), update it instead
if [ $? -ne 0 ]; then
  echo "Secret exists, updating..."
  aws secretsmanager update-secret \
    --secret-id "${SECRET_NAME}" \
    --secret-string "${SECRET_VALUE}" \
    --region "${REGION}"
fi

echo "✅ Secret ${SECRET_NAME} created/updated successfully"
echo "Channel ID: ${CHANNEL_ID}"
