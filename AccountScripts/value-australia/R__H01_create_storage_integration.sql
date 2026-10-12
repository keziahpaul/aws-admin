

{% from 'modules/create_s3_storage_integration.j2' import create_s3_storage_integration-%}
--create logging integration in snowflake account

{% set external_id = in_sf_external_id+in_sf_env+'_valueaustralia_pdg_s3_integration' %}

{{ create_s3_storage_integration('valueaustralia_pdg_s3',in_pdg_account_no,in_va_pdg_role_name,external_id,in_pdg_s3_bucket,in_value_australia_s3_key,in_sf_env) }}


