{% from 'modules/create_warehouse.j2' import create_snowpark_warehouse -%}

--creating warehouse for data transformation
{{create_snowpark_warehouse(in_sf_env, 'TRN_M', 'MEDIUM', 1, 60, 'This warehouse used for data transformation')}}
