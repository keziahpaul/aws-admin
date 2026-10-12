import os
import json
import boto3
import csv
import io
import logging
from datetime import datetime, timezone
from botocore.exceptions import ClientError
from urllib.parse import unquote_plus
import urllib3

# Initialize AWS clients
s3 = boto3.client('s3')
secrets_manager = boto3.client('secretsmanager')

# Environment variables
environment = os.environ.get('ENVIRONMENT', 'dev')
source_bucket = os.environ.get('S3_LANDING_BUCKET')
target_bucket = os.environ.get('S3_VERIFIED_BUCKET')
slack_webhook_secret = os.environ.get('SLACK_WEBHOOK_SECRET', 'onedata-slack-app-bot-token')

# Load enabled applications and their configuration
enabled_applications = json.loads(os.environ.get('ENABLED_APPLICATIONS', '[]'))
data_sources_config = json.loads(os.environ.get('DATA_SOURCES_CONFIG', '{}'))

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


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
        logger.error(f"Error fetching secret {secret_name}: {e}")
        raise


def get_slack_config():
    """Get Slack configuration from Secrets Manager"""
    try:
        secret = get_secret(slack_webhook_secret)
        return {
            'token': secret.get('token') or secret.get('bot_token'),
            'channels': secret.get('channels', {'default': secret.get('channel_id')})
        }
    except Exception as e:
        logger.warning(f"Failed to get Slack config: {e}")
        return None


def notify_slack(message, data_source):
    """Send notification to Slack"""
    try:
        config = get_slack_config()
        if not config or not config['token']:
            logger.warning("Slack token not configured")
            return

        channels = config['channels']
        channel_id = channels.get(data_source.lower(), channels.get('default'))

        if not channel_id:
            logger.warning(f"No Slack channel configured for {data_source}")
            return

        if message.startswith('✅'):
            emoji = ':white_check_mark:'
            title = f"*{data_source.title()} - File Processed Successfully* [`{environment.upper()}`]"
        else:
            emoji = ':x:'
            title = f"*{data_source.title()} - Validation Failed* [`{environment.upper()}`]"

        payload = json.dumps({
            "channel": channel_id,
            "text": f"{emoji} {title}\n\n{message}"
        })
        headers = {
            "Authorization": f"Bearer {config['token']}",
            "Content-Type": "application/json"
        }
        http = urllib3.PoolManager()
        response = http.request("POST", "https://slack.com/api/chat.postMessage", body=payload, headers=headers)
        resp_data = json.loads(response.data.decode('utf-8'))
        if response.status == 200 and resp_data.get('ok'):
            logger.info(f"Slack notification sent successfully for {data_source} to {channel_id}")
        else:
            logger.warning(f"Failed to send Slack notification: {response.status} - {resp_data}")
    except Exception as e:
        logger.warning(f"Error sending Slack notification: {e}")


def load_validation_config(data_source, report_type):
    """
    Load validation configuration from the verified (ingress) bucket.
    Path: {data_source}/config/{report_type}/validation_rules.json
    """
    config_key = f"{data_source}/config/{report_type}/validation_rules.json"
    try:
        response = s3.get_object(Bucket=target_bucket, Key=config_key)
        config = json.loads(response['Body'].read().decode('utf-8'))
        logger.info(f"Loaded validation config from s3://{target_bucket}/{config_key}")
        return config
    except Exception as e:
        logger.error(f"Failed to load validation config from s3://{target_bucket}/{config_key}: {e}")
        raise


def validate_file_extension(file_name, allowed_extensions):
    """Validate file extension"""
    file_ext = os.path.splitext(file_name)[1].lower()
    return file_ext in allowed_extensions


def validate_csv_schema(file_content, validation_rules):
    """Validate CSV file against schema rules"""
    try:
        # Strip BOM if present
        if file_content.startswith('\ufeff'):
            file_content = file_content[1:]

        csv_reader = csv.reader(io.StringIO(file_content))
        headers = next(csv_reader)

        required_columns = validation_rules.get('required_columns', [])
        if required_columns != headers:
            return False, f"Header mismatch. Expected: {required_columns}, Got: {headers}", 0

        row_count = 0
        val_rules = {v["name"]: v for v in validation_rules.get('column_types', [])}
        csv_dict_reader = csv.DictReader(io.StringIO(file_content))
        for row in csv_dict_reader:
            if not any(cell.strip() for cell in row.values()):
                continue

            row_count += 1

            for key, cell in row.items():
                column_def = val_rules.get(key, {})
                if column_def and not validate_data_type(cell, column_def.get('type'), column_def.get('format')):
                    expected_fmt = column_def.get('format')
                    fmt_hint = f" (expected format: {expected_fmt})" if expected_fmt else ""
                    return False, f"Invalid data type in row {csv_dict_reader.line_num}, {key}: '{cell}'{fmt_hint}", row_count

        if row_count == 0:
            return False, "File contains no data rows", 0

        return True, "Validation successful", row_count

    except Exception as e:
        return False, f"CSV validation error: {str(e)}", 0


def validate_data_type(value, expected_type, date_format=None):
    """Validate individual cell data type"""
    if not value.strip():
        return True

    try:
        if expected_type == 'string':
            return True
        elif expected_type == 'number':
            float(value)
            return True
        elif expected_type == 'date':
            datetime.strptime(value, date_format or '%Y-%m-%d')
            return True
        else:
            return True
    except (ValueError, TypeError):
        return False


def build_verified_key(data_source, report_type, file_name):
    """
    Build target key: {data_source}/verified/{report_type}/{YYYYMMDD}/{report_type}_{YYYYMMDD}.{ext}

    Uses a standardised filename based on report_type and today's UTC date.
    Any re-upload on the same day overwrites the same destination file,
    regardless of the source filename.
    """
    today = datetime.now(timezone.utc).strftime('%Y%m%d')
    ext = os.path.splitext(file_name)[1].lower()
    standardised_name = f"{report_type}_{today}{ext}"
    return f"{data_source}/verified/{report_type}/{today}/{standardised_name}"


def move_file_to_verified(source_key, target_key):
    """Copy file from landing bucket to verified bucket, then delete the file."""
    try:
        copy_source = {'Bucket': source_bucket, 'Key': source_key}
        s3.copy_object(CopySource=copy_source, Bucket=target_bucket, Key=target_key)
        s3.delete_object(Bucket=source_bucket, Key=source_key)

        # Re-create the folder marker so the prefix remains visible in S3 console
        folder_prefix = source_key.rsplit('/', 1)[0] + '/'
        s3.put_object(Bucket=source_bucket, Key=folder_prefix, Body=b'')

        logger.info(f"Moved s3://{source_bucket}/{source_key} -> s3://{target_bucket}/{target_key}")
        return True
    except Exception as e:
        logger.error(f"Failed to move file: {e}")
        return False


def lambda_handler(event, context):
    """
    Main Lambda handler.

    Landing bucket key:  {data_source}/uploaded/{report_type}/{file_name}
    Verified bucket key: {data_source}/verified/{report_type}/{YYYYMMDD}/{file_name}
    Validation config:   {data_source}/config/{report_type}/validation_rules.json (in verified bucket)
    """
    for record in event['Records']:
        bucket_name = None
        file_key = None
        data_source = 'Unknown'
        report_type = 'Unknown'
        try:
            bucket_name = record['s3']['bucket']['name']
            file_key = unquote_plus(record['s3']['object']['key'])
            file_name = os.path.basename(file_key)

            logger.info(f"Processing file: {file_key}")

            # Expected: {data_source}/uploaded/{report_type}/{file_name}
            path_parts = file_key.split('/')
            if len(path_parts) < 4:
                raise ValueError(
                    f"Invalid file path: {file_key}. "
                    f"Expected: {{data_source}}/uploaded/{{report_type}}/{{file_name}}"
                )

            data_source = path_parts[0]
            report_type = path_parts[2]
            data_source_key = data_source.lower()

            if data_source_key not in enabled_applications:
                logger.warning(f"Data source {data_source} is not enabled. Skipping: {file_key}")
                continue

            logger.info(f"Processing {data_source}/{report_type}: {file_name}")

            # Load per-report-type validation config from verified bucket
            validation_config = load_validation_config(data_source, report_type)

            # Validate file extension
            allowed_extensions = validation_config.get('allowed_extensions', ['.csv'])
            if not validate_file_extension(file_name, allowed_extensions):
                raise ValueError(f"Invalid file extension. Allowed: {allowed_extensions}")

            # Get and validate file content
            response = s3.get_object(Bucket=bucket_name, Key=file_key)
            file_content = response['Body'].read().decode('utf-8')

            is_valid, validation_message, row_count = validate_csv_schema(file_content, validation_config)

            if is_valid:
                target_key = build_verified_key(data_source, report_type, file_name)
                if move_file_to_verified(file_key, target_key):
                    logger.info(f"File {file_name} validated and moved successfully")
                    notify_slack(
                        f"✅ File processed successfully\n\n"
                        f"Source: `s3://{bucket_name}/{file_key}`\n"
                        f"Destination: `s3://{target_bucket}/{target_key}`\n"
                        f"Report Type: `{report_type}`\n"
                        f"Rows: {row_count}",
                        data_source
                    )
                else:
                    raise Exception("Failed to move file to verified bucket")
            else:
                logger.error(f"Validation failed for {file_name}: {validation_message}")
                notify_slack(
                    f"❌ Validation failed\n\n"
                    f"Bucket: `{bucket_name}`\n"
                    f"File: `{file_key}`\n"
                    f"Report Type: `{report_type}`\n"
                    f"Error: {validation_message}",
                    data_source
                )

        except Exception as e:
            logger.error(f"Error processing file {file_key}: {str(e)}")
            notify_slack(
                f"❌ Processing error\n\n"
                f"Bucket: `{bucket_name or 'unknown'}`\n"
                f"File: `{file_key or 'unknown'}`\n"
                f"Report Type: `{report_type}`\n"
                f"Error: {str(e)}",
                data_source
            )
