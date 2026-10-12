{% from 'modules/create_database_schema.j2' import create_database_schema-%}

--creating  database and  schema for env {{in_sf_env}}

{% if ((in_sf_acc_name).lower() != 'exchange' ) %}

{{create_database_schema(in_sf_env,'SANDBOX','de_sandbox')}}
{{create_database_schema(in_sf_env,'SANDBOX','di_sandbox')}}
{{create_database_schema(in_sf_env,'SANDBOX','ds_sandbox')}}

{% else %}

    select 1

{% endif %}
