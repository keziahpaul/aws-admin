{% import 'modules/user.j2' as user with context -%}
{% import 'modules/role.j2' as role with context -%}

--creating all required admin roles for env
-- s - service users
-- n - notify users
{{ user.create('github', 'S') }}
{{ user.create('dbt', 'S') }}
{{ user.create('fivetran', 'S') }}
{{ user.create('census', 'S') }} -- no type specified, so defaults to user
{{ user.create('alation', 'S') }}
{{ user.create('tableau', 'S') }} -- no type specified, so defaults to user
{{ user.create('sagemaker', 'S') }}
{{ user.create('slack', 'S', email='some_random_email@org.slack.com') }} -- no type specified, so defaults to user
{{ user.create('slack_job', 'N', email='some_other_random_email@org.slack.com') }}

use role useradmin;

create user if not exists DEV_GITHUB_INTEGRATION_USER;
ALTER USER DEV_GITHUB_INTEGRATION_USER
SET TYPE = 'SERVICE';

alter user DEV_SLACK_JOB_NOTIFICATION_USER set password = null ;


use role securityadmin;

{{ role.create('DATA_GOVERNANCE', 'A')}}
{{ role.create('DATADABSE', 'A')}}

{{ role.create('GITHUB', 'S') }}
{{ role.create('DBT', 'S') }}
{{ role.create('FIVETRAN', 'S') }}
{{ role.create('CENSUS', 'S') }}
{{ role.create('ALATION', 'S') }}
{{ role.create('TABLEAU', 'S') }}
{{ role.create('SAGEMAKER', 'S') }}


grant role DEV_GITHUB_INTEGRATION_ROLE_S TO USER DEV_GITHUB_INTEGRATION_USER;
grant role DEV_DBT_INTEGRATION_ROLE_S TO USER DEV_DBT_INTEGRATION_USER;
grant role DEV_FIVETRAN_INTEGRATION_ROLE_S TO USER DEV_FIVETRAN_INTEGRATION_USER;
grant role DEV_CENSUS_INTEGRATION_ROLE_S TO USER DEV_CENSUS_INTEGRATION_USER;
grant role DEV_ALATION_INTEGRATION_ROLE_S TO USER DEV_ALATION_INTEGRATION_USER;
grant role DEV_TABLEAU_INTEGRATION_ROLE_S TO USER DEV_TABLEAU_INTEGRATION_USER;
grant role DEV_SAGEMAKER_INTEGRATION_ROLE_S TO USER DEV_SAGEMAKER_INTEGRATION_USER;

grant role sysadmin to role DEV_github_integration_role_s;
grant role securityadmin to role DEV_github_integration_role_s;
grant role useradmin to role DEV_github_integration_role_s;

grant role security_network_admin to role sysadmin;

grant usage on database DEV_metadata to role DEV_GITHUB_INTEGRATION_ROLE_S;
grant usage on schema DEV_metadata.schemachange to role DEV_GITHUB_INTEGRATION_ROLE_S;
grant select, insert, update, delete, truncate on table DEV_metadata.schemachange.change_history to role DEV_GITHUB_INTEGRATION_ROLE_S;


create role if not exists OKTA_PROVISIONER;
{{ role.create('ANALYST', 'F') }}
{{ role.create('ENGINEER', 'F') }}
{{ role.create('DI_ANALYST', 'F') }}
{{ role.create('SUPPORT', 'F') }}
{{ role.create('SCIENTIST', 'F') }}
{{ role.create('DATA_STEWARD', 'F') }}
{{ role.create('DATA_GOVERNANCE_SPECIALIST', 'F') }}

create role if not exists SECOPS_F;

grant role securityadmin to role SECOPS_F;


revoke role DEV_DBT_INTEGRATION_ROLE_S from role sysadmin;
grant role sysadmin to role DEV_DBT_INTEGRATION_ROLE_S;

revoke role DEV_FIVETRAN_INTEGRATION_ROLE_S from role sysadmin;
grant role sysadmin to role DEV_FIVETRAN_INTEGRATION_ROLE_S;


grant role DEV_ANALYST_F to role sysadmin;
grant role DEV_ENGINEER_F to role sysadmin;
grant role DEV_DI_ANALYST_F to role sysadmin;
grant role DEV_SUPPORT_F to role sysadmin;
grant role DEV_SCIENTIST_F to role sysadmin;
grant role DEV_DATA_STEWARD_F to role sysadmin;
grant role DEV_DATA_GOVERNANCE_SPECIALIST_F to role sysadmin;


grant usage on database DEV_metadata to role DEV_ENGINEER_F;
grant usage on schema DEV_metadata.schemachange to role DEV_ENGINEER_F;
grant select, references on all tables  in schema DEV_metadata.schemachange to role DEV_ENGINEER_F;


grant usage on database DEV_metadata to role DEV_SUPPORT_F;
grant usage on schema DEV_metadata.schemachange to role DEV_SUPPORT_F;
grant select, references on all tables  in schema DEV_metadata.schemachange to role DEV_SUPPORT_F;


use role accountadmin;

grant database role SNOWFLAKE.OBJECT_VIEWER to role DEV_ALATION_INTEGRATION_ROLE_S;
grant database role SNOWFLAKE.GOVERNANCE_VIEWER to role DEV_ALATION_INTEGRATION_ROLE_S;
grant database role SNOWFLAKE.USAGE_VIEWER to role DEV_ALATION_INTEGRATION_ROLE_S;


grant database role SNOWFLAKE.OBJECT_VIEWER to role DEV_DBT_INTEGRATION_ROLE_S;
grant database role SNOWFLAKE.GOVERNANCE_VIEWER to role DEV_DBT_INTEGRATION_ROLE_S;
grant database role SNOWFLAKE.USAGE_VIEWER to role DEV_DBT_INTEGRATION_ROLE_S;
grant database role SNOWFLAKE.SECURITY_VIEWER to role DEV_DBT_INTEGRATION_ROLE_S;


grant database role SNOWFLAKE.GOVERNANCE_VIEWER to role SECOPS_F;
grant database role SNOWFLAKE.SECURITY_VIEWER to role SECOPS_F;

grant database role SNOWFLAKE.GOVERNANCE_VIEWER to role DEV_ANALYST_F;
grant database role SNOWFLAKE.GOVERNANCE_VIEWER to role DEV_ENGINEER_F;
grant database role SNOWFLAKE.GOVERNANCE_VIEWER to role DEV_DI_ANALYST_F;
grant database role SNOWFLAKE.GOVERNANCE_VIEWER to role DEV_SUPPORT_F;
grant database role SNOWFLAKE.GOVERNANCE_VIEWER to role DEV_SCIENTIST_F;
grant database role SNOWFLAKE.GOVERNANCE_VIEWER to role DEV_DATA_GOVERNANCE_SPECIALIST_F;
grant database role SNOWFLAKE.GOVERNANCE_VIEWER to role DEV_DATA_STEWARD_F;


grant database role SNOWFLAKE.OBJECT_VIEWER to role DEV_ANALYST_F;
grant database role SNOWFLAKE.OBJECT_VIEWER to role DEV_ENGINEER_F;
grant database role SNOWFLAKE.OBJECT_VIEWER to role DEV_DI_ANALYST_F;
grant database role SNOWFLAKE.OBJECT_VIEWER to role DEV_SUPPORT_F;
grant database role SNOWFLAKE.OBJECT_VIEWER to role DEV_SCIENTIST_F;
grant database role SNOWFLAKE.OBJECT_VIEWER to role DEV_DATA_GOVERNANCE_SPECIALIST_F;
grant database role SNOWFLAKE.OBJECT_VIEWER to role DEV_DATA_STEWARD_F;


grant imported privileges on database snowflake to role sysadmin;
grant imported privileges on database snowflake to role securityadmin;


alter account set MIN_DATA_RETENTION_TIME_IN_DAYS=0 ;
alter account set DATA_RETENTION_TIME_IN_DAYS=0 ;
alter account set enable_unredacted_query_syntax_error=true;


{{ role.create('DI_ANALYST_PUBLIC', 'F') }}
{{ role.create('DATA_SCIENTIST_PUBLIC', 'F') }}

grant role DEV_DI_ANALYST_PUBLIC_F to role sysadmin;
grant role DEV_DATA_SCIENTIST_PUBLIC_F to role sysadmin;

grant database role SNOWFLAKE.OBJECT_VIEWER to role DEV_DI_ANALYST_PUBLIC_F;
grant database role SNOWFLAKE.OBJECT_VIEWER to role DEV_DATA_SCIENTIST_PUBLIC_F;
grant database role SNOWFLAKE.GOVERNANCE_VIEWER to role DEV_DI_ANALYST_PUBLIC_F;
grant database role SNOWFLAKE.GOVERNANCE_VIEWER to role DEV_DATA_SCIENTIST_PUBLIC_F