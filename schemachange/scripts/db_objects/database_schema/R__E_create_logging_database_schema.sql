{% from 'modules/create_database_schema.j2' import create_database_schema-%}

--creating  database and  schema for env {{in_sf_env}}

{{create_database_schema(in_sf_env,'LOGGING','DBT_LOGS')}}
{{create_database_schema(in_sf_env,'LOGGING','FIVETRAN_LOGS')}}
{{create_database_schema(in_sf_env,'LOGGING','SPLUNK_LOGGING')}}
{{create_database_schema(in_sf_env,'LOGGING','TRUSTCENTER')}}