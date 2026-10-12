{% from 'modules/create_s3_storage_integration.j2' import create_s3_storage_integration-%}
--create logging integration in snowflake account

{{ create_s3_storage_integration('LOGGING',log_aws_account_no,log_iam_role,log_external_id,log_s3_path,log_s3_key,in_sf_env) }}

 
       