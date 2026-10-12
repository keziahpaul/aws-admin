{% from 'modules/create_admin_roles.j2' import create_admin_roles-%}

--creating all required admin roles for env {{in_sf_env}} 

{{create_admin_roles(in_sf_env,in_sf_acc_name,params_dict)}}

