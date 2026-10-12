----- IMPORTANT NOTE: ALTER EXISTING NETWORK POLICY, in future if any new IPS for Value australia needs to be added please add a alter stament if not exists else, update your IP in existing ALTER statement

use role SECURITYADMIN;


--******** STEP2- Create network Policies*****************************************************


CREATE NETWORK POLICY IF NOT EXISTS enabled_glue_IPV4_network ;

--4. Allowed  glue network IPs 

{% if ((in_sf_env).lower() == 'dev' ) or ((in_sf_env).lower() == 'tst') %}
ALTER NETWORK POLICY IF  EXISTS enabled_glue_IPV4_network set ALLOWED_IP_LIST= {{nonprod_ip_list}};
{% endif %}

{% if ((in_sf_env).lower() == 'pst') or ((in_sf_env).lower() == 'prd') %}
ALTER NETWORK POLICY IF  EXISTS enabled_glue_IPV4_network set ALLOWED_IP_LIST= {{ prod_ip_list }};
{% endif %}


ALTER USER {{ in_sf_env }}_GLUE_INTEGRATION_USER SET NETWORK_POLICY = enabled_glue_IPV4_network;