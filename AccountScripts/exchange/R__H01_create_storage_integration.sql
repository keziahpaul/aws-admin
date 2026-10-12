
{% from 'modules/create_s3_storage_integration.j2' import create_s3_storage_integration-%}
--create logging integration in snowflake account
{% set api_logs_external_id = in_sf_external_id+in_sf_env+'_exchange_apilogs_s3_integration' %}
{% set api_logs_role = in_sf_env+'-'+in_exchange_api_logs_role_name %}

{{ create_s3_storage_integration('exchange_apilogs_s3',in_exchange_account_no,api_logs_role,api_logs_external_id,in_exchange_api_logs_s3_bucket,"",in_sf_env) }}

--create pexakey snowflake integration in aws

{% set pexakey_external_id = in_sf_external_id+'exch_pexakey_s3_integration_'+in_sf_env %}
{% set pexakey_role = 'onedata-pexakey-snowflake-integration-role-'+in_sf_env %}
{% set exchange_pexakey_s3_bucket = 'onedata-pexakey-'+data_aws_account_no+'-'+in_sf_env %}

{{ create_s3_storage_integration('exchange_pexakey_s3',data_aws_account_no,pexakey_role,pexakey_external_id,exchange_pexakey_s3_bucket,"",in_sf_env) }}
