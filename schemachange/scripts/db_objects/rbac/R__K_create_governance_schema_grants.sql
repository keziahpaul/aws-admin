{% from 'modules/create_access_roles_privileges.j2' import create_access_roles_privileges-%}

{{create_access_roles_privileges(in_sf_env,'GOVERNANCE_DB','COMPLIANCE','all','TRN_XS_WH')}}

{% set db_name       = in_sf_env + "_" + 'GOVERNANCE_DB' %}
USE ROLE ACCOUNTADMIN;
grant create tag on schema {{db_name}}.COMPLIANCE to role {{ in_sf_env }}_dbt_integration_role_s;
grant apply tag on account to role {{ in_sf_env }}_dbt_integration_role_s;

grant create masking policy on schema {{db_name}}.COMPLIANCE to role {{ in_sf_env }}_dbt_integration_role_s;
grant apply masking policy on account to role {{ in_sf_env }}_dbt_integration_role_s;

create database role if not exists {{db_name}}.READER_DB_ROLE_A;

grant usage on database {{db_name}} to database role {{db_name}}.READER_DB_ROLE_A;
grant usage on schema {{db_name}}.compliance to database role {{db_name}}.READER_DB_ROLE_A;

grant database role {{db_name}}.READER_DB_ROLE_A to role {{ in_sf_env }}_alation_integration_role_s;

grant database role {{db_name}}.READER_DB_ROLE_A to role {{ in_sf_env }}_DATA_GOVERNANCE_SPECIALIST_F;





