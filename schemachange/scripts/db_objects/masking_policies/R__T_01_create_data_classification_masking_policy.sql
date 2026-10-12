{% from 'modules/create_snowflake_masking_policies.j2' import create_masking_policy-%}

{% if ((in_sf_acc_name).lower()!='group-azure' ) %}

{% set masking_db='governance_db' -%}
{% set masking_schema='compliance' -%}
{% set mp_db= in_sf_env~'_'~masking_db~'.'~masking_schema%}
{% set mp_update= false %}
{% set string_policies=
['PI_BUSINESS_NAME',
'PI_CONTACT_NUMBER',
'PI_EMAIL',
'PI_FAX',
'PI_FREE_TEXT_FIELD',
'PI_FULL_ADDRESS',
'PI_FULL_NAME',
'PI_NAME',
'PI_PARTIAL_ADDRESS',
'PI_SENSITIVE',
'PI_SENSITIVE_FINANCIAL',
'PI_USERID'] -%}

{% set date_policies=['PI_DOB'] -%}
{% set variant_policies=['PI_MULTI'] -%}
{% set number_policies=['PI_USERID','PI_SENSITIVE_FINANCIAL'] -%}
{% set boolean_policies=['PI_SENSITIVE'] -%}

{% for policy in string_policies %}

{{create_masking_policy(
    in_sf_env,
    masking_db= masking_db,
    masking_schema=masking_schema,
    mp_name = policy,
    val_type='string',
    masked_pattern='regexp_replace(val,\'[^ ]\',\'*\')',
    comment='masking policy for tag {{ policy }}. Full text Redaction.',
    update_policy=mp_update
)}}

{% endfor -%}

{% for policy in date_policies %}

{{create_masking_policy(
    in_sf_env,
    masking_db= masking_db,
    masking_schema=masking_schema,
    mp_name =policy,
    val_type='date',
    masked_pattern='replace( date_trunc(year, val), date_part( year,val),date_part( year,TO_DATE(\'1900-01-01\')))',
    comment='masking policy for tag {{ policy }}. 	Date Default depending on format.',
    update_policy=mp_update
)}}

{% endfor -%}

{% for policy in variant_policies %}

{{create_masking_policy(
    in_sf_env,
    masking_db= masking_db,
    masking_schema=masking_schema,
    mp_name =policy,
    val_type='variant',
    masked_pattern=mp_db~'.JSON_MASK_FUNC(val)',
    comment='masking policy for tag {{ policy }}, masks values in key/val pairs',
    update_policy=mp_update
)}}

{% endfor -%}

{% for policy in number_policies %}

{{create_masking_policy(
    in_sf_env,
    masking_db= masking_db,
    masking_schema=masking_schema,
    mp_name =policy,
    val_type='number',
    masked_pattern='0',
    comment='number masking policy for tag ' ~ policy,
    update_policy=mp_update,
    append_datatype=true
)}}

{% endfor -%}

{% for policy in boolean_policies %}

{{create_masking_policy(
    in_sf_env,
    masking_db= masking_db,
    masking_schema=masking_schema,
    mp_name =policy,
    val_type='boolean',
    masked_pattern='NULL',
    comment='boolean masking policy for tag ' ~ policy,
    update_policy=mp_update,
    append_datatype=true
)}}

{% endfor -%}

{% else %}
    select 1
{% endif %}