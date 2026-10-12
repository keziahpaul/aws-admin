{% from 'modules/create_csv_file_format.j2' import create_csv_file_format-%}

-- Create the file format that will be used when offloading our logs into S3
-- We're creating the file format and other objects that require to be created
-- in a schema in the LOGGING DB and SNOWFLAKE_LOGS schema.

{{create_csv_file_format(in_sf_env,'LOGGING','LOGGING','SPLUNK_LOGGING')}}
