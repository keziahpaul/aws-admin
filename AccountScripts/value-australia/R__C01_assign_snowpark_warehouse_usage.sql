use role securityadmin;

--assign snowpark warehouse to all transformation roles
grant usage on warehouse {{ in_sf_env }}_TRN_M_SP_WH to role {{ in_sf_env }}_DBT_INTEGRATION_ROLE_S;
