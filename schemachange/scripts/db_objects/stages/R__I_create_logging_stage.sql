{% from 'modules/create_stage.j2' import create_stage-%}
--create logging stage in logging db and snowflake_logs schema

{{ create_stage(in_sf_env,'LOGGING','SPLUNK_LOGGING','LOGGING','LOGGING_INTEGRATION',log_s3_path,log_s3_key,log_kms_key_id) }} 
