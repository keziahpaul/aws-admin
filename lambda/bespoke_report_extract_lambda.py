import os
from os.path import basename
from io import BytesIO
import boto3
from botocore.exceptions import ClientError
import requests
import email
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
import msal
import base64
import io
import json
from datetime import datetime
import pytz
import csv
import pyzipper
import logging
import re
import html


s3 = boto3.client('s3')
secrets_manager = boto3.client('secretsmanager')
environment = os.environ.get('ENVIRONMENT', "dev").lower()
logger = logging.getLogger()
PARAM_PREFIX="bespoke_report_delivery_params/"
PARAM_SUFFIX=".json"
base_report_name_re = re.compile(r'([0-9]{4}(-?)[0-9]{2}\2[0-9]{2}_)?(.*?)(( - |[-_])([0-9]{8}(_[0-9]{6})?|[A-Za-z]{3}[0-9]{2}))?\.(csv|dat)$', re.I)
SMTP_SECRET_NAME = "reporting2_email"
# TEMP_PREFIX = 'temp/bankwest_cba_cbb/'
# Process only files from allowed folders (whitelist)
# ignores other folders such as TEMP_PREFIX and PARAM_PREFIX
ALLOWED_FOLDERS = ['anz/', 'cba/', 'westpac/', 'nab/','stockland/', 'internal/', 'fms/', 'bendigo/']

DEFAULT_DATA_TBL_STYLE = """
#data-tbl {
    border: 1px solid #000;
    border-collapse: collapse;
    font-family: Arial, sans-serif;
    font-size: 12px;
}
#data-tbl tr {
    border: 1px solid #000;
}
#data-tbl th,
#data-tbl td {
    border: 1px solid #000;
    padding: 8px;
}
#data-tbl th {
    background-color: #f2f2f2;
    text-align: left;
}
""".strip()

# Format rules for different report types
REPORT_FORMAT_RULES = {
    "Westpac_Daily_report": {
        "subject_format": "default_subject",
        "zip_file_name_format": "no_datetime" # <report_name>.zip
    },
    "Bankwest_to_CBA": {
        "subject_format": "concat_datetime_space",
        "zip_file_name_format": "custom_cba_cbb"
    },
    "Bankwest_to_CBB": {
        "subject_format": "concat_datetime_space",
        "zip_file_name_format": "custom_cba_cbb"
    },
    "ANZ_FSS_signatures": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "concat_datetime"
    },
    "ANZ_Proceeds_no_MORT": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "concat_datetime"
    },
    "NAB_Incident_Reporting_AM": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "concat_datetime"
    },
    "NAB_Incident_Reporting_1PM": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "concat_datetime"
    },
    "NAB_Incident_Reporting_PM_SETTLED": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "concat_datetime"
    },
    "NAB_Incident_Reporting_PM_from_Today": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "concat_datetime"
    },
    "PEXAUserReportProduction": {
        "s3_file_name_format": "prefix_datetime"
    },
    "PEXACommercialloansAppProduction_Prod": {
        "s3_file_name_format": "prefix_datetime"
    },
    "PEXARetailAppProduction_Prod": {
        "s3_file_name_format": "prefix_datetime"
    },
    "Trust_delta_trust_accounts": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "concat_datetime"
    },
    "PEXAProjectsData_Stockland": {
        "subject_format": "concat_file_name",
        "zip_file_name_format": "NO_ZIP"
    },
    "PEXAProjectsData_Stockland_GST_Witholding": {
        "subject_format": "concat_file_name",
        "zip_file_name_format": "NO_ZIP"
    },
    "FMS_TG_weekly_report": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "concat_datetime"
    },
    "FMS_SoT_weekly_report": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "concat_datetime"
    },
    "Workspace_summary_reporting_CBA": {
        "subject_format": "default_subject",
        "zip_file_name_format": "file_name"
    },
    "NAB_On_Day_Settlement": {
        "subject_format": "default_subject",
        "zip_file_name_format": "file_name"
    },
    "Bendigo_ADL_On_Day_Settlement": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "concat_datetime"
    },
    "Bendigo_BBL_On_Day_Settlement": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "concat_datetime"
    },
    "Bendigo_BBLBA_On_Day_Settlement": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "concat_datetime"
    },
    "NAB_Sign_Not_On_Time_Extract": {
        "zip_file_name_format": "file_name"
    },
    "FMS_SOT_daily_report": {
        "subject_format": "concat_datetime_underscore",
        "zip_file_name_format": "file_name"
    },
    "ANZ_Sign_Not_On_Time_Extract": {
        "zip_file_name_format": "file_name"
    },
    "InappropriateSourceAcct_delta": {
        "zip_file_name_format": "NO_ZIP"
    },
    "ANZ_BIRecon": {
        "subject_format": "concat_file_name",
        "zip_file_name_format": "NO_ZIP"
    }
}

MULTI_FILE_GROUPS = {
    "Bankwest_CBA_CBB": {
        "members": ["Bankwest_to_CBA", "Bankwest_to_CBB"],
        "zip_name": "Bankwest_to_CBA_CBB_{date}.zip",
        "subject": "Bankwest refinances to CBA/CBB extract {date}",
        "TEMP_PREFIX": "temp/bankwest_cba_cbb/"
    },
    "Westpac_WBG_RAM_WEEKLY": {
        "members": ["Westpac_weekly_report", "Westpac_Rams_weekly_report"],
        "zip_name": "Westpac_weekly_report.zip",
        "subject": "Westpac Group Discharge Report PEXA",
        "TEMP_PREFIX": "temp/westpac_weekly/"
    },
    "Westpac_WBG_RAM_MONTHLY": {
        "members": ["Westpac_Monthly_report", "Westpac_Rams_Monthly_report"],
        "zip_name": "Westpac_Monthly_report_{date}.zip",
        "subject": "Westpac Group Discharge Report PEXA",
        "TEMP_PREFIX": "temp/westpac_monthly/"
    },
    "FMS_weekly_report": {
        "members": ["FMS_TG_weekly_report", "FMS_SoT_weekly_report"],
        "zip_name": "FMS_weekly_report_{date}.zip",
        "subject": "FMS_weekly_report_{date}",
        "TEMP_PREFIX": "temp/fms/"
    },
    "Bendigo_Bank_On_Day_Settlement_Reports": {
        "members": ["Bendigo_ADL_On_Day_Settlement", "Bendigo_BBL_On_Day_Settlement", "Bendigo_BBLBA_On_Day_Settlement"],
        "zip_name": "Bendigo_Bank_On_Day_Settlement_Reports_{date}.zip",
        "subject": "Bendigo Bank On Day Settlement (ODS) Reports",
        "TEMP_PREFIX": "temp/bendigo/"
    }
}

def get_secret(secret_name):
    try:
        response = secrets_manager.get_secret_value(SecretId=secret_name)
        if 'SecretString' in response:
            return json.loads(response['SecretString'])
        elif 'SecretBinary' in response:
            return json.loads(response['SecretBinary'].decode('utf-8'))
        else:
            raise KeyError(f"Neither 'SecretString' nor 'SecretBinary' found in secret {secret_name}")
    except ClientError as e:
        raise Exception(f"Error fetching secret {secret_name}: {e}")

def get_slack_webhook_url():
    """Fetch the Slack webhook URL dynamically based on the environment."""
    # Determine the secret name based on the environment
    if environment in ["pst", "prf", "prd"]:
        secret_name = "onedata_prod_notification_slack_url"
    else:
        secret_name = "onedata_nonprod_dev_notification_slack_url"

    try:
        # Fetch the secret from AWS Secrets Manager
        secret = get_secret(secret_name)
        if isinstance(secret, dict):
            return secret.get(secret_name)
        return secret
    except ClientError as e:
        logger.warning(f"Error fetching secret '{secret_name}' for environment '{environment}': {e}")
        raise

# Slack webhook
SLACK_WEBHOOK_URL = get_slack_webhook_url()

# Function to send failure notifications to Slack
def notify_slack(message):
    try:
        payload = {"text": message}
        requests.post(SLACK_WEBHOOK_URL, json=payload)
    except Exception as e:
        logger.warning(f"Failed to send Slack notification: {e}")

def fetch_delivery_config(bucket_name, param_file_key):
    """ Fetches and parses delivery configuration based off of delivery type"""
    try:
        param_file_obj = s3.get_object(Bucket=bucket_name, Key=param_file_key)
        return json.loads(param_file_obj['Body'].read())
    except Exception as err:
        logger.warning(err)
        raise Exception(f"Error fetching parameter file {param_file_key}: {err}")

def create_archive(zip_buffer, password):
    if password:
        zf = pyzipper.AESZipFile(zip_buffer, 'w', compression=pyzipper.ZIP_DEFLATED, encryption=pyzipper.WZ_AES)
        zf.setpassword(password.encode('utf-8') if isinstance(password, str) else password)
    else:
        zf = pyzipper.ZipFile(zip_buffer, 'w', compression=pyzipper.ZIP_DEFLATED)
    return zf

def create_multi_file_zip_buffer(files_dict, password_secret_path=None):
    """Creates a zip buffer with one or more files, with or without a password.

    Args:
        files_dict: Dictionary mapping filenames to file contents
        password_secret_path: Optional dict with 'secret_name' and 'key' for password retrieval

    Returns:
        BytesIO buffer containing the zip file
    """
    zip_buffer = io.BytesIO()
    password = None

    try:
        # Get password from secrets if path provided
        if password_secret_path and password_secret_path.get("secret_name") and password_secret_path.get("key"):
            secret_name = password_secret_path.get("secret_name")
            logger.info("Successfully fetched secret_name from password_secret_path.")
            key = password_secret_path.get("key")
            logger.info("Successfully fetched secret key password_secret_path.")
            password = get_secret(secret_name).get(key)
            logger.info("Successfully fetched password from secret.")

        # Create zip with or without password
        with create_archive(zip_buffer, password) as zf:
            for file_name, file_content in files_dict.items():
                if not file_name.lower().endswith('.csv'):
                    file_name = os.path.splitext(file_name)[0] + '.csv'
                zf.writestr(file_name, file_content.encode('utf-8') if isinstance(file_content, str) else file_content)

        zip_buffer.seek(0)
        return zip_buffer
    except Exception as e:
        err = f"Error creating zip file: {e}"
        logger.error(err)
        raise Exception(err)

def store_temp_csv(bucket_name, base_report_name, file_date, processed_file_content,TEMP_PREFIX):
    temp_key = f"{TEMP_PREFIX}{base_report_name}_{file_date}.csv"
    s3.put_object(
        Bucket=bucket_name,
        Key=temp_key,
        Body=processed_file_content,
        Metadata={'trigger-source': 'lambda-generated'}
    )
    return temp_key

def process_file_to_csv(file_content, headerfooter, header_count, file_date, base_report_name):
    """ Process files that are .dat format and write to csv"""
    csv_input = io.StringIO(file_content.decode('utf-8'))
    csv_reader = csv.reader(csv_input, delimiter=',', quotechar='"')

    csv_buffer = io.StringIO()
    csv_writer = csv.writer(csv_buffer, delimiter=',', lineterminator='\n')

    # used for footer "9"
    row_count = 0

    header = []
    # Special header for PEXAUserReportProduction
    if base_report_name == "PEXAUserReportProduction":
        # Format: 'Date/Time Generated: DD/MM/YYYY HH:MM TIMEZONE'
        header = [datetime.now(pytz.timezone('Australia/Sydney')).strftime('Date/Time Generated: %d/%m/%Y %H:%M %Z')]
    # Standard header for other reports
    elif headerfooter:
        header = ["0", file_date]

    if header:
        csv_writer.writerow(header)

    # Write the data rows
    for row in csv_reader:
        csv_writer.writerow(row)
        row_count += 1

    data_row_count = row_count - header_count

    # Append the footer row with count of data rows (skip for PEXAUserReportProduction)
    if headerfooter and header_count != 0 and base_report_name != "PEXAUserReportProduction":
        csv_writer.writerow(["9", data_row_count])

    # Reset the buffer pointer to the beginning
    csv_buffer.seek(0)
    return csv_buffer.getvalue(), data_row_count


def send_email(recipients, cc, bcc, subject, body, sender, attachment, file_name):
    """ Sends email with the given parameters """
    msg = MIMEMultipart()
    msg['Subject'] = subject
    msg['From'] = sender
    msg['To'] = ", ".join(recipients)
    msg['Bcc'] = ", ".join(bcc)
    msg['Cc'] = ", ".join(cc)
    msg.attach(MIMEText(body, "html"))

    # Attach zipped file to email
    attachment = MIMEApplication(attachment.getvalue())
    attachment.add_header('Content-Disposition', 'attachment', filename=file_name)
    msg.attach(attachment)

    try:
        # Get OAuth credentials from secrets manager
        email_secret = get_secret(SMTP_SECRET_NAME)
        tenant_id = email_secret["tenant_id"]
        client_id = email_secret["client_id"]
        client_secret = email_secret["client_secret"]

        # Acquire OAuth token
        logger.info("Acquiring OAuth token for Graph API")
        app = msal.ConfidentialClientApplication(
            client_id,
            authority=f"https://login.microsoftonline.com/{tenant_id}",
            client_credential=client_secret
        )
        
        token_result = app.acquire_token_for_client(["https://graph.microsoft.com/.default"])
        if "access_token" not in token_result:
            raise RuntimeError(f"Token acquisition failed: {token_result}")
        
        access_token = token_result["access_token"]
        logger.info("OAuth token acquired successfully")

        # Send email via Graph API
        logger.info(f"Sending email from {sender} to {', '.join(recipients)}")
        response = requests.post(
            f"https://graph.microsoft.com/v1.0/users/{sender}/sendMail",
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "text/plain"
            },
            data=base64.encodebytes(msg.as_bytes())
        )

        if response.status_code == 202:
            logger.info("Email sent successfully via Graph API")
        else:
            raise RuntimeError(f"Failed to send email: {response.status_code} - {response.text}")
            
    except Exception as e:
        logger.error(f"Error sending email: {e}")
        raise
    


def handle_default_report_logic(file_name, subject, base_report_name, current_date, lv_member_date=None):
    """Handles default logic for reports not explicitly listed."""
    # Fetch rules for the report
    report_rules = REPORT_FORMAT_RULES.get(base_report_name, {})
    subject_format = report_rules.get("subject_format", None)
    zip_file_name_format = report_rules.get("zip_file_name_format", "no_datetime")
    # Format the subject based on the rule
    if subject_format == "concat_datetime_underscore":
        formatted_subject = f"{subject}_{current_date}"
    elif subject_format == "concat_datetime_space":
        formatted_subject = f"{subject} {current_date}"
    elif subject_format == "concat_full_datetime_underscore":
        full_datetime = lv_member_date if lv_member_date else current_date
        formatted_subject = f"{subject}_{full_datetime}"
    elif subject_format == "concat_file_name":
        formatted_subject = f"{subject}{file_name}"
    else:
        formatted_subject = subject  # Default to the original subject

    # Format the zip file name based on the rule
    if zip_file_name_format == "concat_datetime":
        zip_file_name = f"{base_report_name}_{current_date}"
    elif zip_file_name_format == "no_datetime":
        zip_file_name = base_report_name
    elif zip_file_name_format == "file_name":
        zip_file_name = f"{os.path.splitext(file_name)[0]}.zip"
    else:
        # Extract the base file name and ignore the file extension
        base_file_name, _ = os.path.splitext(file_name)
        zip_file_name = base_file_name

    return formatted_subject, zip_file_name,zip_file_name_format

def get_subject_and_zip_name(base_report_name, subject, file_name, current_date, lv_member_date=None):
    """Determines the subject, zip file name, and attachment name based on the report type."""
    # Handle specific reports
    if base_report_name in ["Bankwest_to_CBA", "Bankwest_to_CBB"]:
        formatted_subject = f"{subject} {current_date}"
        zip_file_name = f"Bankwest_to_CBA_CBB_{current_date}.zip"

    elif base_report_name == "Westpac_Daily_report":
        formatted_subject = subject  # No change to the subject passed from config file
        zip_file_name = f"{base_report_name}.zip"

    elif base_report_name in ["ANZ_FSS_signatures", "ANZ_Proceeds_no_MORT"]:
        formatted_subject = f"{subject}_{current_date}"
        zip_file_name = f"{base_report_name}_{current_date}.zip"

    elif base_report_name in ["NAB_Incident_Reporting_AM", "NAB_Incident_Reporting_1PM", "NAB_Incident_Reporting_PM_Settled", "NAB_Incident_Reporting_PM_from_Today"]:
        formatted_subject = f"{subject}_{current_date}"
        zip_file_name = f"{base_report_name}_{current_date}.zip"

    elif base_report_name in ["Trust_delta_trust_accounts"]:
        formatted_subject = f"{subject}_{current_date}"
        zip_file_name = f"{base_report_name}_{current_date}.zip"

    else:
        # Default logic for other reports
        return handle_default_report_logic(file_name, subject, base_report_name, current_date, lv_member_date)

    return formatted_subject, zip_file_name,'NA'

def handle_email_delivery(file_name, processed_file_content, sender, subject, body, recipients, cc, bcc,password_secret_path, base_report_name, bucket_name, current_date,lv_member_date):
    try: 
        # Special handling for Bankwest_to_CBA and Bankwest_to_CBB
        # if base_report_name in ["Bankwest_to_CBA", "Bankwest_to_CBB"]: --- replace teh CBA logic to include more such file zipping
        group = next(
            (g for g in MULTI_FILE_GROUPS.values() if base_report_name in g["members"]),
            None
        )

        if group:
            store_temp_csv(bucket_name, base_report_name, current_date, processed_file_content,group["TEMP_PREFIX"])

            try:
                files_to_zip = {}

                for member in group["members"]:
                    key = f"{group["TEMP_PREFIX"]}{member}_{current_date}.csv"
                    obj = s3.get_object(Bucket=bucket_name, Key=key)
                    if lv_member_date:
                        files_to_zip[f"{member}_{current_date}.csv"] = obj['Body'].read()
                    else:
                        files_to_zip[f"{member}.csv"] = obj['Body'].read()

                # If we got here, all files exist
                zip_buffer = create_multi_file_zip_buffer(files_to_zip, password_secret_path)

                zip_file_name = group["zip_name"].format(date=current_date)
                formatted_subject = group["subject"].format(date=current_date)

                send_email(
                    recipients,
                    cc,
                    bcc,
                    formatted_subject,
                    body,
                    sender,
                    zip_buffer,
                    zip_file_name
                )

                logger.info(f"Multi-file email sent successfully to {', '.join(recipients)}")

                # Cleanup
                for member in group["members"]:
                    key = f"{group["TEMP_PREFIX"]}{member}_{current_date}.csv"
                    s3.delete_object(Bucket=bucket_name, Key=key)

                logger.info("Temp files cleaned up.")

            except s3.exceptions.NoSuchKey:
                logger.info(f"Waiting for all files in group {group['members']}")

            except Exception as e:
                error_msg = f"Failed to send grouped email: {e}"
                logger.error(error_msg)
                notify_slack(error_msg)

            return
            

        # Default logic for other reports (NO password) 
        formatted_subject, zip_file_name, zip_file_format = get_subject_and_zip_name(base_report_name, subject, file_name, current_date,lv_member_date)
        if zip_file_format=='NO_ZIP':
            # Send raw file without zipping
            raw_buffer = BytesIO(processed_file_content.encode('utf-8') if isinstance(processed_file_content, str) else processed_file_content)
            send_email(recipients, cc, bcc, formatted_subject, body, sender, raw_buffer, file_name)
        else:
            zip_buffer = create_multi_file_zip_buffer({zip_file_name: processed_file_content}, password_secret_path)
            send_email(recipients, cc, bcc,formatted_subject, body, sender, zip_buffer,zip_file_name)
        
        logger.info(f"Email sent successfully to {', '.join(recipients)}")
    except Exception as e:
        logger.warning(f"Error sending email: {e}")
        notify_slack(f"Error sending email: {e}")

def handle_s3_delivery(file_name, processed_file_content, target_bucket, target_folders, base_report_name, file_date):
    """Handles S3 delivery of the file."""
    try:
        folder_path = "/".join(target_folders) if target_folders else ""

        # Get S3 filename format rule for this report
        report_rules = REPORT_FORMAT_RULES.get(base_report_name, {})
        s3_file_name_format = report_rules.get("s3_file_name_format", "original")

        # Format the S3 filename based on the rule
        if s3_file_name_format == "prefix_datetime":
            # Format as YYYYMMDD_filename.csv
            s3_file_name = f"{file_date}_{base_report_name}.csv"
        else:
            # Use original filename
            s3_file_name = file_name

        s3_key = f"{folder_path}/{s3_file_name}" if folder_path else s3_file_name
        logger.debug(f"target_bucket {target_bucket}")
        logger.debug(f"folder_path {folder_path}")
        logger.debug(f"s3_key {s3_key}")

        s3.put_object(Bucket=target_bucket, Key=s3_key, Body=processed_file_content, ACL='bucket-owner-full-control')
        logger.info(f"File successfully uploaded '{s3_file_name}' to S3 bucket '{target_bucket}/{s3_key}'.")
    except Exception as e:
        logger.warning(f"Error uploading file to S3: {e}")
        notify_slack(f"Error uploading file to S3: {e}")

def resolve_body_template(body, processed_file_content, header_count, row_count, style=None):
    """Replace template placeholders in email body with actual values.
    
    Supported placeholders:
        {{row_count}} - Number of data rows in the file (excludes header rows)
        {{data_table}} - HTML table of the CSV data (header row becomes <th>, data rows become <td>)
    """
    if "{{row_count}}" not in body and "{{data_table}}" not in body:
        return body

    if "{{row_count}}" in body:
        body = body.replace("{{row_count}}", str(row_count))
    
    if "{{data_table}}" in body:
        csv_input = io.StringIO(processed_file_content)
        csv_reader = csv.reader(csv_input, delimiter=',', quotechar='"')

        table_html = '<table id="data-tbl">\n'

        for i, row in enumerate(csv_reader):
            if i < header_count:
                table_html += '<tr>' + ''.join(f'<th>{html.escape(cell)}</th>' for cell in row) + '</tr>\n'
            else:
                table_html += '<tr>' + ''.join(f'<td>{html.escape(cell)}</td>' for cell in row) + '</tr>\n'

        table_html += '</table>'

        # Inject style into <head> - use default if not provided in config
        style = style or DEFAULT_DATA_TBL_STYLE
        style_block = f'<style>{style}</style>'
        if '<head>' in body:
            body = body.replace('</head>', style_block + '</head>')
        elif '<body>' in body:
            body = body.replace('<body>', '<head>' + style_block + '</head><body>')
        else:
            body = style_block + body

        body = body.replace("{{data_table}}", table_html)

    return body


def shim_s3(file_name, proc_file, config, delivery, base_report_name, bucket_name, current_date, lv_member_date, row_count):
   for target in delivery:
       handle_s3_delivery(file_name, proc_file, target["target_bucket"], target["target_folders"], base_report_name, current_date)

def shim_email(file_name, proc_file, config, delivery, base_report_name, bucket_name, current_date, lv_member_date, row_count):
   for target in delivery:
        body = resolve_body_template(target["body"], proc_file, config.get("header_count", 0), row_count, target.get("style"))
        handle_email_delivery(file_name, proc_file, target["from"], target["subject"], body, target["recipients"], target.get("cc", []), target.get("bcc", []), config.get("password_secret_path", {}), base_report_name, bucket_name, current_date, lv_member_date)

delivery_fns = {"email": shim_email, "s3": shim_s3}

def lambda_handler(event, context):
    debug = os.environ.get('DEBUG', "")
    if debug:
        logger.setLevel(logging.DEBUG)
    else:
        logger.setLevel(logging.INFO)

    for record in event['Records']:
        try:
            # When one or more files is dropped into the bucket
            bucket_name = record['s3']['bucket']['name']
            file_key = record['s3']['object']['key']

            folder_path = os.path.dirname(file_key).lower()

            # Skip files not in allowed folders
            # also prevents recursive invocation of lambda when files are put into TEMP_PREFIX or manual upload into PARAM_PREFIX
            if not any(folder_path.startswith(folder) for folder in ALLOWED_FOLDERS):
                logger.info(f"Skipping file {file_key} - not in allowed folders")
                continue
            # Extract the file name from file key path
            file_name = os.path.basename(file_key)

            matched = base_report_name_re.match(file_name)
            if matched:
                # Extract date from filename
                g = matched.groups()
                base_report_name = g[2]
                # file_date = (g[3][len(g[4]):-len(g[5]) if g[5] else len(g[3])] if g[3] else None
                #     ) or (g[0].strip('_').replace(g[1], '') if g[0] else None
                #           ) or datetime.now(pytz.timezone('Australia/Sydney')).strftime('%Y%m%d')
                raw_date = (
                    g[5] if g[5]
                    else (g[0].strip('_').replace(g[1], '') if g[0] else None)
                )

                if raw_date:
                    if re.fullmatch(r'\d{8}_\d{6}', raw_date):
                        file_date = raw_date[:8]
                    elif re.fullmatch(r'\d{8}', raw_date):
                        file_date = raw_date
                    elif re.fullmatch(r'[A-Za-z]{3}\d{2}', raw_date):
                        file_date = raw_date.title()
                    else:
                        raise Exception(f"Unsupported date format extracted from filename: {raw_date}")
                else:
                    file_date = datetime.now(pytz.timezone('Australia/Sydney')).strftime('%Y%m%d')
                logger.info(f"Extracted date {file_date} from filename {file_name}")
            else:
                raise Exception(f"Invalid file name format: {file_name}")

            # Determine the parameter file key based on the uploaded file's name
            param_file_key = PARAM_PREFIX + base_report_name + PARAM_SUFFIX

            # Fetch the bespoke parameter file
            config = fetch_delivery_config(bucket_name, param_file_key)

            file_obj = s3.get_object(Bucket=bucket_name, Key=file_key)
            file_content = file_obj['Body'].read()

            # Process file content - always use current date for header/footer
            processed_file_content, row_count = process_file_to_csv(
                file_content,
                config.get('source', {}).get("headerfooter", False),
                config.get('source', {}).get("header_count", 0),
                file_date,
                base_report_name
            )

            # Use file date for all delivery types
            for delivery_type, delivery_config in config["delivery_type"].items():
                handler = delivery_fns.get(delivery_type.lower(), None)
                if handler:
                    logger.info(f"Using file date {file_date} for {delivery_type} delivery")
                    handler(file_name,
                            processed_file_content,
                            config["source"],
                            delivery_config,
                            base_report_name,
                            bucket_name,
                            file_date,
                            raw_date,
                            row_count
                            )
                else:
                    error_message = f"Unsupported delivery type: {delivery_type}"
                    logger.warning(error_message)
                    notify_slack(error_message)

        except Exception as e:
            error_message = f"Error processing file {file_key}: {e}"
            logger.warning(error_message)
            notify_slack(error_message)
