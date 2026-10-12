--  this script is designed to run as a one time only.


-- reducing the query timeout (Snowflake defaults to 172800 ie., 48hrs)
alter account set statement_timeout_in_seconds = 3600;
alter user {{ in_sf_env }}_DBT_INTEGRATION_USER set statement_timeout_in_seconds = {{ in_statement_timeout_at }};
