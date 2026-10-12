# **PEXA-One-Data-AWS-Admin**
This GitHub repository contains Cloudformation templates and workflows to create the following AWS services/resources:

## S3 ##
To create a S3 bucket with KMS, refer to the resources.yml cloudformation template.

> Deployment GitHub workflow: deploy.yml

## IAM ##
To create an IAM role in an AWS account, to access other resources like S3, refer to the iam.yml cloudformation template.

> Non-Prod Deployment GitHub workflow: iam-nonprod-deploy.yml
>
> Prod Deployment GitHub workflow: iam-prod-deploy.yml

Use case: This workflow uses a reusable-iam-deploy workflow and can be extended to any AWS account by specifing the AWSAccountNumber.


## Bespoke Lambda workflow

[Bespoke Lambda logic flow](lambda/README.md)

## Bespoke Report Params JSON file usage ##

This aims to explain how to configure and use the JSON parameter files for delivering bespoke reports via Email or S3.

### **Trigger Rules:**

__Important__ JSON param names must match file name

The parameter file name must exactly match the **base name** of the report file (case-sensitive) to ensure proper processing.

#### **Allowed Folders:**

The Lambda function will only process files from the following folders and any subfolders (case-insensitive):
- `anz/`
- `cba/`
- `westpac/`

Files in other folders will be skipped and not processed.

#### **Temporary Files:**

For reports Bankwest to CBA/CBB, the Lambda creates temporary files in the S3 bucket under the `temp/bankwest_cba_cbb/` prefix. These files:

1. Are tagged with metadata `{'trigger-source': 'lambda-generated'}` to identify them
2. Are automatically cleaned up after successful email delivery
3. Will remain in S3 if email delivery fails, allowing for troubleshooting
4. Will not trigger recursive Lambda processing

1. **Base Name Matching**:
   - The parameter file name should match the report file's name **excluding the date and file extension**.
   - Example:
     - Report file: `Asdf_Daily_report_20250414.csv`
     - Parameter file: `Asdf_Daily_report.json`

2. **Case Sensitivity**:
   - Both the report file name and the parameter file name are **case-sensitive**.
   - Example:
     - If the report file is `ASDf_Daily_report_20250414.csv`, the parameter file must be `ASDf_Daily_report.json` (not `asdf_daily_report.json`).

3. **Location**:
   - The parameter file must be stored in the S3 bucket under the prefix:
     `bespoke_report_delivery_params/` _s3://pexa-onedata-egress-${DataAWSAccount}$-${environment}/bespoke_report_delivery_params/_

4. **Invalid Example**:
   - Report file: `ASDf_Daily_report_20250414.csv`
   - Parameter file: `ASDF_Daily_Report.json` (incorrect due to case mismatch).

### Logic

Regex: `base_report_name_re = re.compile(r'([0-9]{4}(-?)[0-9]{2}\2[0-9]{2}_)?(.*?)(( - |[-_])[0-9]{8}(_[0-9]{6})?)?\.(csv|dat)$', re.I)
`

`re.I` will ignore case in file extension. Will match `.CSV`, `.dAt` etc

| File Name                              | Matches?       | Base Report Name         |
|----------------------------------------|----------------|--------------------------|
| `Westpac_Daily_report_20250408.csv`    | **Yes**        | `Westpac_Daily_report`   |
| `CM0346581.csv`                        | **Yes**        | `CM0346581`              |
| `A00671_W_ED_WBC_20250408.dat`         | **Yes**        | `A00671_W_ED_WBC` |
| `20250408_PEXAUserReportProduction.csv` | **Yes** | `PEXAUserReportProduction` |


```
Scenario 1: File Name with Date at the Start
- Input: 20250408_PEXAUserReportProduction.csv
- Regex Match:
    - Group 1: "20250408_" (date prefix).
    - Group 2: None (no separator in the date prefix).
    - Group 3: "PEXAUserReportProduction" (base report name).
    - Group 4: None (no date suffix).
    - Group 5: None (no separator before the date suffix).
    - Group 6: None (no time component)
    - Group 7: "csv" (file extension).
- Result: Matches.
Base Report Name: "PEXAUserReportProduction"

Scenario 2: File Name with Date at the End
- Input: Westpac_Daily_report_20250408.csv
- Regex Match:
    - Group 1: None (no date prefix).
    - Group 2: None (no separator in the date prefix).
    - Group 3: "Westpac_Daily_report" (base report name).
    - Group 4: "_20250408" (date suffix).
    - Group 5: "_" (separator before the date suffix).
    - Group 6: None (no time component).
    - Group 7: "csv" (file extension).
- Result: Matches.
- Base Report Name: "Westpac_Daily_report"

Scenario 3: File Name without Date
- Input: CM0346581.csv
- Regex Match:
    - Group 1: None (no date prefix).
    - Group 2: None (no separator in the date prefix).
    - Group 3: "CM0346581" (base report name).
    - Group 4: None (no date suffix).
    - Group 5: None (no separator before the date suffix).
    - Group 6: None (no time component).
    - Group 7: "csv" (file extension).
- Result: Matches.
- Base Report Name: "CM0346581"

Scenario 4: File Name with Date and Time in the Suffix
- Input: A00671_W_ED_WBC_20250408_123456.dat
- Regex Match:
    - Group 1: None (no date prefix).
    - Group 2: None (no separator in the date prefix).
    - Group 3: "A00671_W_ED_WBC" (base report name).
    - Group 4: "_20250408_123456" (date and time suffix).
    - Group 5: "_" (separator before the date suffix).
    - Group 6: "_123456" (time component in the format _HHMMSS).
    - Group 7: "dat" (file extension).
Result: Matches.
Base Report Name: "A00671_W_ED_WBC"

Scenario 5: Invalid File Name
- Input: InvalidFileName.txt
- Regex Match: No match (matched = None).
- Result: Does Not Match.
- Output: Raises an exception:
Invalid file name format: InvalidFileName.txt

```

##### **Why This is Important**:
The scenarios demonstrate how the regex matches:

- Matches file names with optional date prefixes (e.g., 20250408_).
- Matches file names with optional date and time suffixes (e.g., _20250408_123456).
- Handles flexible separators (-, -, _) for date suffixes.
- Ensures only .csv or .dat files are processed.
- Rejects invalid file names with unsupported extensions.

### Delivery Mechanisms

#### 1. Email Delivery

- Reports are often zipped and emailed to recipients
- Some reports require to be zipped with password protection
- For reports like Bankwest to CBA/CBB, both files must be present before the email is sent, as the customer expects one zip with both files in it.

**JSON Struct config**
```
{
    "source": {
        "headerfooter": false,
        "header_count": 0,
        "password_secret_path": {
            "secret_name": "dummy_secret",
            "key": "dummy_pw"
        }
    },
    "delivery_type": {
        "email": [
            {
                "from": "reporting2@asdf.com.au",
                "subject": "Test email for XYZ Daily Report",
                "recipients": [
                    "recipient1@asdf.com.au",
                    "recipient2@asdf.com.au",
                    "recipient3@asdf.com.au",
                    "recipient4@asdf.com.au"
                ],
                "cc": [],
                "body": "<html><head></head><body><style class=\"title\" style=\"color: #444444; font-family: 'Lato', Arial, sans-serif; font-weight: 400; mso-line-height-rule: exactly; font-size: 15px; line-height: 160%; text-align: left;\"></style><p>Hi,</p><p>Please find attached the Westpac and St George data extract for completed workspaces.</p><p>Kind regards,<br><a style=\"text-decoration: none; font-weight: 800; color: #80006A\">PEXA Data Team<br></a></p></body></html>"
            }
        ]
    }
}
```
**Key Fields**

- `source.headerfooter`: Specifies whether the report output should include a header with a datetime stamp and a footer containing the total data row count.
- `source.header_count`: The number of header rows present in the source report, used to determine the total count of actual **data** rows.
- `source.password_secret_path`: (Optional) Path to the secret that is used to zip the file.
  - `secret_name`: Name of the secret in AWS Secrets Manager.
  - `key`: Key within the secret containing the password.
- `delivery_type.email`: Indicates delivery mechanism
  - `from`: Sender's email address.
  - `subject`: Email subject.
  - `recipients`: List of recipient email addresses.
  - `cc`: List of CC email addresses (optional).
  - `body`: HTML content for the email body.

__Note__: You can override the default `"email"` config block or add a new "email" block with different recipients, subject and body. This will act as a partial bcc between the recipients in both email blocks

##### Dynamic Email Body Placeholders

The `body` field supports optional template placeholders that are replaced at runtime with values derived from the report data:

| Placeholder | Description |
|---|---|
| `{{row_count}}` | The number of data rows in the report file (excludes header rows based on `source.header_count`) |
| `{{data_table}}` | An HTML table rendering of the CSV data. The table is generated with an id of `data-tbl`. Header rows (based on `source.header_count`) become `<th>` elements, and data rows become `<td>` elements. All cell values are HTML-escaped for safety. |

**Styling the data table:**

The `{{data_table}}` placeholder renders a plain `<table id="data-tbl">` with no inline styling. To style the table, provide a `"style"` field in the email configuration block containing CSS rules targeting `#data-tbl`. The style will be injected into the `<head>` of the email HTML.

**Example config with dynamic body and styling:**
```json
{
    "source": {
        "headerfooter": false,
        "header_count": 1,
        "password_secret_path": {}
    },
    "delivery_type": {
        "email": [
            {
                "from": "reporting2@pexa.com.au",
                "subject": "Data alert - Trust_User_Exception",
                "recipients": ["recipient@pexa.com.au"],
                "cc": [],
                "body": "<html><head></head><body><p>Hi,</p><p>{{row_count}} user(s) have had a name change, and the subscriber operates a trust account.</p>{{data_table}}<p>Kind regards,<br>PEXA Data Team</p></body></html>",
                "style": "#data-tbl { border: 1px solid #000; border-collapse: collapse; font-family: Arial, sans-serif; font-size: 12px; } #data-tbl th, #data-tbl td { border: 1px solid #000; padding: 8px; } #data-tbl th { background-color: #f2f2f2; text-align: left; }"
            }
        ]
    }
}
```

**Key Fields**

- `style`: (Optional) CSS rules for the data table. Must target `#data-tbl` and its child elements (`th`, `td`, `tr`). Injected into the email `<head>` as a `<style>` block. Only required when using `{{data_table}}`.

**Notes:**
- If `{{row_count}}` or `{{data_table}}` are not present in the `body`, no template processing occurs — the body is sent as-is.
- Ensure the `body` includes a `<head></head>` tag for proper style injection when using `{{data_table}}` with a `"style"` field.
- Reports that do not use these placeholders are completely unaffected.


#### 2. S3

- Reports are pushed to an S3 bucket from `Data AWS` account to `Core AWS` account (cross account)

**JSON Struct**
```
{
    "source": {
        "headerfooter": true,
        "header_count": 1
    },
    "delivery_type": {
        "S3": [
            {
                "target_bucket": "asdf-S3-target-bucket",
                "target_folders": ["pushed", "to", "this", "path"]
            }
        ]
    }
}
```

**Key Fields**

- `source.headerfooter`: Specifies whether the report output should include a header with a datetime stamp and a footer containing the total data row count.
- `source.header_count`: The number of header rows present in the source report, used to determine the total count of actual **data** rows.

- `delivery_type.S3`:
  - `target_bucket`: Name of the S3 bucket where the report will be uploaded.
  - `target_folders`: (Optional) Path within the bucket where the report will be pushed to.
    - Example:
        - target_bucket: "asdf-S3-target-bucket"
        - target_folders: ["2025", "January"]

    Here the report will be pushed to `"asdf-S3-target-bucket/2025/January"`
