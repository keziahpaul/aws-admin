{% from 'modules/create_warehouse.j2' import create_warehouse-%}

---------------------------------create warehouse------------------------------------------------------
 --creating warehouse for tableau
    {{create_warehouse(in_sf_env,'TABLEAU_XS','XSMALL',1,60,'This warehouse used by Tablueau users to access data')}}
    {{create_warehouse(in_sf_env,'TABLEAU_S','SMALL',1,60,'This warehouse used by Tablueau users to access data')}}
    {{create_warehouse(in_sf_env,'TABLEAU_M','MEDIUM',1,60,'This warehouse used by Tablueau users to access data')}}

 --creating warehouse for batch process
    {{create_warehouse(in_sf_env,'BATCH_XS','XSMALL',1,60,'This warehouse used for batch ingestion')}}
    {{create_warehouse(in_sf_env,'BATCH_S','SMALL',1,60,'This warehouse used for batch ingestion')}}
    {{create_warehouse(in_sf_env,'BATCH_M','MEDIUM',1,60,'This warehouse used for batch ingestion')}}

 --creating warehouse for real time batch process
    {{create_warehouse(in_sf_env,'REAL_TIME_BATCH_XS','XSMALL',1,60,'This warehouse used for real time batch ingestion')}}
    {{create_warehouse(in_sf_env,'REAL_TIME_BATCH_S','SMALL',1,60,'This warehouse used for real time batch ingestion')}}
    {{create_warehouse(in_sf_env,'REAL_TIME_BATCH_M','MEDIUM',1,60,'This warehouse used for real time batch ingestion')}}

 --creating warehouse for analytical process
    {{create_warehouse(in_sf_env,'ANALYTICS_XS','XSMALL',1,60,'This warehouse used for analytical purposes' )}}
    {{create_warehouse(in_sf_env,'ANALYTICS_S','SMALL',1,60,'This warehouse used for analytical purposes')}}
    {{create_warehouse(in_sf_env,'ANALYTICS_M','MEDIUM',1,60,'This warehouse used for analytical purposes')}}

 --creating  warehouse for  data transformation
    {{create_warehouse(in_sf_env,'TRN_XS','XSMALL',1,60,'This warehouse used for  data transformation')}}
    {{create_warehouse(in_sf_env,'TRN_S','SMALL',1,60,'This warehouse used for  data transformation')}}
    {{create_warehouse(in_sf_env,'TRN_M','MEDIUM',1,60,'This warehouse used for  data transformation')}}

 --creating  warehouse for alation 
    {{create_warehouse(in_sf_env,'ALATION_XS','XSMALL',1,60,'This warehouse used by alation to access  data')}}
    {{create_warehouse(in_sf_env,'ALATION_S','SMALL',1,60,'This warehouse used by alation to access  data')}}
    {{create_warehouse(in_sf_env,'ALATION_M','MEDIUM',1,60,'This warehouse used by alation to access  data')}}

  --creating  warehouse for census 
    {{create_warehouse(in_sf_env,'CENSUS_XS','XSMALL',1,60,'This warehouse used by census to access  data')}}
    {{create_warehouse(in_sf_env,'CENSUS_S','SMALL',1,60,'This warehouse used by census to access  data')}}
    {{create_warehouse(in_sf_env,'CENSUS_M', 'MEDIUM',1,60,'This warehouse used by census to access  data')}}

  --creating  warehouse for sagemaker 
    {{create_warehouse(in_sf_env,'SAGEMAKER_XS','XSMALL',1,60,'This warehouse used by sagemaker to access  data')}}
    {{create_warehouse(in_sf_env,'SAGEMAKER_S','SMALL',1,60,'This warehouse used by sagemaker to access  data')}}
    {{create_warehouse(in_sf_env,'SAGEMAKER_M', 'MEDIUM',1,60,'This warehouse used by sagemaker to access  data')}}

   --creating  warehouse for glue 
   {{create_warehouse(in_sf_env,'GLUE_XS','XSMALL',1,60,'This warehouse used by sagemaker to access  data')}}
    {{create_warehouse(in_sf_env,'GLUE_S','SMALL',1,60,'This warehouse used by sagemaker to access  data')}}
    {{create_warehouse(in_sf_env,'GLUE_M', 'MEDIUM',1,60,'This warehouse used by sagemaker to access  data')}}

   --creating  warehouse for bigid
    {{create_warehouse(in_sf_env,'BIGID_XS','XSMALL',1,60,'This warehouse used by BigID for data classification')}}


 --creating  warehouse for developer 
    {{create_warehouse(in_sf_env,'DEVELOPER_XS','XSMALL',1,60,'This warehouse used by onedata developers')}}

