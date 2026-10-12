{% from 'modules/create_row_access_policy.j2' import create_row_access_policy-%}

{% set mp_update= false %}

{{create_row_access_policy(
    in_sf_env,
    policy_name='row_access_policy',
    masking_db='governance_db',
    masking_schema='compliance',
    column_name = 'id',
    column_typ='string',
    update_policy=mp_update
)}}