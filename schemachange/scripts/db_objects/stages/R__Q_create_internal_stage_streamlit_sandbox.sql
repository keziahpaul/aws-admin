{% if ((in_sf_acc_name).lower() != 'exchange' and in_sf_acc_name.lower() != 'group-azure' and ((in_sf_env.lower() == 'dev') or (in_sf_env.lower() == 'tst') or (in_sf_env.lower() == 'prd'))) %}
USE ROLE SYSADMIN;


CREATE STAGE IF NOT EXISTS {{ in_sf_env }}_SANDBOX.DE_SANDBOX.{{ in_sf_env }}_STREAMLIT_APPS;

{% else %}
select 1;
{% endif %}
