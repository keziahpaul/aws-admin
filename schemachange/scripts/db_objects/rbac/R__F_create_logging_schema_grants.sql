{% from 'modules/create_access_roles_privileges.j2' import create_access_roles_privileges-%}

--creating RBACs for env {{in_sf_env}}

{{create_access_roles_privileges(in_sf_env,'LOGGING','SPLUNK_LOGGING','all','TRN_XS_WH')}}
{{create_access_roles_privileges(in_sf_env,'LOGGING','DBT_LOGS','all','TRN_XS_WH')}}
{{create_access_roles_privileges(in_sf_env,'LOGGING','FIVETRAN_LOGS','all','TRN_XS_WH')}}
{{create_access_roles_privileges(in_sf_env,'LOGGING','TRUSTCENTER','all','TRN_XS_WH')}}

