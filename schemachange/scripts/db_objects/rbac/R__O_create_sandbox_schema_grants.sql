{% from 'modules/create_special_roles_grants.j2' import create_special_roles_grants-%}

--creating RBACs for env {{in_sf_env}}

{% if ((in_sf_acc_name).lower() != 'exchange' ) %}

{{create_special_roles_grants(in_sf_acc_name,in_sf_env,'SANDBOX','de_sandbox')}}
{{create_special_roles_grants(in_sf_acc_name,in_sf_env,'SANDBOX','di_sandbox')}}
{{create_special_roles_grants(in_sf_acc_name,in_sf_env,'SANDBOX','ds_sandbox')}}

{% else %}
    select 1
{% endif %}