
{% from 'modules/create_snowflake_tag.j2' import create_tags-%}

{% if ((in_sf_acc_name).lower()!='group-azure' ) %}

{# --------------------------------creating streamlit tag in sandbox and group account-----------------------#}
{% set tag_db='governance_db' -%}
{% set tag_schema='compliance' -%}
  
 
{% set data_classification_tags=
['PI_BUSINESS_NAME',
'PI_CONTACT_NUMBER',
'PI_DOB',
'PI_EMAIL',
'PI_FAX',
'PI_FREE_TEXT_FIELD',
'PI_FULL_ADDRESS',
'PI_FULL_NAME',
'PI_MULTI',
'PI_NAME',
'PI_PARTIAL_ADDRESS',
'PI_SENSITIVE',
'PI_SENSITIVE_FINANCIAL',
'PI_USERID'] -%}

{% for value in data_classification_tags %}
{{create_tags(
    in_sf_env=in_sf_env,
    tag_db=tag_db, 
    tag_schema=tag_schema, 
    tag_name= value ,
    comment='This tag is for data classification'
    )}}

{% endfor %}

{% else %}
    select 1
{% endif %}