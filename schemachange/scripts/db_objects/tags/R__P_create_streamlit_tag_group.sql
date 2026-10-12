
{% from 'modules/create_snowflake_tag.j2' import create_tags-%}

{% if ((in_sf_acc_name).lower() != 'exchange' and (in_sf_acc_name).lower()!='group-azure' ) %}

{# --------------------------------creating streamlit tag in sandbox and group account-----------------------#}
{% set tag_db='governance_db' -%}
{% set tag_schema='compliance' -%}

{{create_tags(
    in_sf_env=in_sf_env,
    tag_db=tag_db, 
    tag_schema=tag_schema, 
    tag_name='streamlit',
    comment='This tag is for streamlit warehouse',
    allowed_values=['Account management','Account management practitioners','Pexa products','Pexa features','Customer support','Marketing','Enterprise','Data engineering','Data science']
    )}} 

{% else %}
    select 1
{% endif %}