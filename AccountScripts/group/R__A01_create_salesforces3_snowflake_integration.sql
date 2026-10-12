
{% from 'modules/create_s3_storage_integration.j2' import create_s3_storage_integration-%}
--create logging integration in snowflake account to add integration
{% set external_id = in_sf_external_id+in_sf_env+'_salesforce_s3_integration' %}
{% set iam_role = 'onedata-s3-ingress-snowflake-integration-role-'+in_sf_env %}

{{ create_s3_storage_integration('group_ingress_s3',data_aws_account_no,iam_role,external_id,in_ingress_s3_bucket,'',in_sf_env) }}
