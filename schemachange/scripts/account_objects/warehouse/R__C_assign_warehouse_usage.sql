
---------------------------------grant warehouse------------------------------------------------------
    use role securityadmin;

 --assign X-small warehouse to all service roles
    grant usage on warehouse {{ in_sf_env }}_ALATION_XS_WH to role {{ in_sf_env }}_ALATION_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_BATCH_XS_WH to role {{ in_sf_env }}_FIVETRAN_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_TRN_XS_WH to role {{ in_sf_env }}_DBT_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_CENSUS_XS_WH to role {{ in_sf_env }}_CENSUS_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_TABLEAU_XS_WH to role {{ in_sf_env }}_TABLEAU_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_SAGEMAKER_XS_WH to role {{ in_sf_env }}_SAGEMAKER_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_BIGID_XS_WH to role {{ in_sf_env }}_BIGID_INTEGRATION_ROLE_S;

    grant usage on warehouse  {{ in_sf_env }}_admin_xs_wh to role {{ in_sf_env }}_github_integration_role_s;

 --assign small warehouse to all service roles
    grant usage on warehouse {{ in_sf_env }}_ALATION_S_WH to role {{ in_sf_env }}_ALATION_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_BATCH_S_WH to role {{ in_sf_env }}_FIVETRAN_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_TRN_S_WH to role {{ in_sf_env }}_DBT_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_CENSUS_S_WH to role {{ in_sf_env }}_CENSUS_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_TABLEAU_S_WH to role {{ in_sf_env }}_TABLEAU_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_SAGEMAKER_S_WH to role {{ in_sf_env }}_SAGEMAKER_INTEGRATION_ROLE_S;

 



 --assign medium warehouse to all service roles
    grant usage on warehouse {{ in_sf_env }}_ALATION_M_WH to role {{ in_sf_env }}_ALATION_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_BATCH_M_WH to role {{ in_sf_env }}_FIVETRAN_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_TRN_M_WH to role {{ in_sf_env }}_DBT_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_CENSUS_M_WH to role {{ in_sf_env }}_CENSUS_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_TABLEAU_M_WH to role {{ in_sf_env }}_TABLEAU_INTEGRATION_ROLE_S;
    grant usage on warehouse {{ in_sf_env }}_SAGEMAKER_M_WH to role {{ in_sf_env }}_SAGEMAKER_INTEGRATION_ROLE_S;

 --assign developer warehouse to all functional roles
    grant usage on warehouse {{ in_sf_env }}_DEVELOPER_XS_WH to role {{ in_sf_env }}_ENGINEER_F;
    grant usage on warehouse {{ in_sf_env }}_DEVELOPER_XS_WH to role {{ in_sf_env }}_SUPPORT_F;
    grant usage on warehouse {{ in_sf_env }}_DEVELOPER_XS_WH to role {{ in_sf_env }}_DI_ANALYST_F;
    grant usage on warehouse {{ in_sf_env }}_DEVELOPER_XS_WH to role {{ in_sf_env }}_ANALYST_F;
    grant usage on warehouse {{ in_sf_env }}_DEVELOPER_XS_WH to role {{ in_sf_env }}_SCIENTIST_F;
    grant usage on warehouse {{ in_sf_env }}_DEVELOPER_XS_WH to role {{ in_sf_env }}_DATA_GOVERNANCE_SPECIALIST_F;
 




---------------------------------set default warehouse for service users-----------------------------------------------------
    use role useradmin;
-- {{ in_sf_env }}_admin_xs_wh is expected to be provisioned as part of account setup, along with
-- the schemachange metadata management table.  As such, it is not part of this code base.
    ALTER USER {{ in_sf_env }}_GITHUB_INTEGRATION_USER SET DEFAULT_WAREHOUSE = {{ in_sf_env }}_admin_xs_wh;
    ALTER USER {{ in_sf_env }}_ALATION_INTEGRATION_USER SET DEFAULT_WAREHOUSE = {{ in_sf_env }}_ALATION_XS_WH;
    ALTER USER {{ in_sf_env }}_FIVETRAN_INTEGRATION_USER SET DEFAULT_WAREHOUSE = {{ in_sf_env }}_BATCH_XS_WH;
    ALTER USER {{ in_sf_env }}_DBT_INTEGRATION_USER SET DEFAULT_WAREHOUSE = {{ in_sf_env }}_TRN_XS_WH;
    ALTER USER {{ in_sf_env }}_CENSUS_INTEGRATION_USER SET DEFAULT_WAREHOUSE = {{ in_sf_env }}_CENSUS_XS_WH;
    ALTER USER {{ in_sf_env }}_TABLEAU_INTEGRATION_USER SET DEFAULT_WAREHOUSE = {{ in_sf_env }}_TABLEAU_XS_WH;
    ALTER USER {{ in_sf_env }}_SAGEMAKER_INTEGRATION_USER SET DEFAULT_WAREHOUSE = {{ in_sf_env }}_SAGEMAKER_XS_WH;
    ALTER USER {{ in_sf_env }}_BIGID_INTEGRATION_USER SET DEFAULT_WAREHOUSE = {{ in_sf_env }}_BIGID_XS_WH;

   {#-- excluded exchange account --#}
   {% if ((in_sf_acc_name).lower() != 'exchange' ) %}
   
   use role securityadmin;

   grant usage on warehouse {{ in_sf_env }}_DEVELOPER_XS_WH to role {{ in_sf_env }}_DI_ANALYST_PUBLIC_F;
   grant usage on warehouse {{ in_sf_env }}_DEVELOPER_XS_WH to role {{ in_sf_env }}_DATA_SCIENTIST_PUBLIC_F;

   {% endif %}