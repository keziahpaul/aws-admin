{% import 'modules/warehouse.j2' as warehouse with context -%}

---------------------------------create warehouse------------------------------------------------------
 --creating warehouse for tableau
{{ warehouse.create('tableau', 'XS', comment='This warehouse used by Tablueau users to access data') }}
{{ warehouse.create('tableau', 'S', comment='This warehouse used by Tablueau users to access data') }}
{{ warehouse.create('tableau', 'M', comment='This warehouse used by Tablueau users to access data') }}

 --creating warehouse for batch process
{{ warehouse.create('batch', 'XS', comment='This warehouse used for batch ingestion') }}
{{ warehouse.create('batch', 'S', comment='This warehouse used for batch ingestion') }}
{{ warehouse.create('batch', 'M', comment='This warehouse used for batch ingestion') }}

 --creating warehouse for real time batch process
{{ warehouse.create('real_time_batch', 'XS', comment='This warehouse used for real time batch ingestion') }}
{{ warehouse.create('real_time_batch', 'S', comment='This warehouse used for real time batch ingestion') }}
{{ warehouse.create('real_time_batch', 'M', comment='This warehouse used for real time batch ingestion') }}

 --creating warehouse for analytical process
{{ warehouse.create('analytics', 'XS', comment='This warehouse used for analytical purposes') }}
{{ warehouse.create('analytics', 'S', comment='This warehouse used for analytical purposes') }}
{{ warehouse.create('analytics', 'M', comment='This warehouse used for analytical purposes') }}

 --creating  warehouse for  data transformation
{{ warehouse.create('trn', 'XS', comment='This warehouse used for data transformation') }}
{{ warehouse.create('trn', 'S', comment='This warehouse used for data transformation') }}
{{ warehouse.create('trn', 'M', comment='This warehouse used for data transformation') }}

  --creating  warehouse for alation
{{ warehouse.create('alation', 'XS', comment='This warehouse used by alation to access data') }}
{{ warehouse.create('alation', 'S', comment='This warehouse used by alation to access data') }}
{{ warehouse.create('alation', 'M', comment='This warehouse used by alation to access data') }}

  --creating  warehouse for census
{{ warehouse.create('census', 'XS', comment='This warehouse used by census to access data') }}
{{ warehouse.create('census', 'S', comment='This warehouse used by census to access data') }}
{{ warehouse.create('census', 'M', comment='This warehouse used by census to access data') }}

  --creating  warehouse for sagemaker
{{ warehouse.create('sagemaker', 'XS', comment='This warehouse used by sagemaker to access data') }}
{{ warehouse.create('sagemaker', 'S', comment='This warehouse used by sagemaker to access data') }}
{{ warehouse.create('sagemaker', 'M', comment='This warehouse used by sagemaker to access data') }}

   --creating  warehouse for glue
{{ warehouse.create('glue', 'XS', comment='This warehouse used by sagemaker to access data') }}
{{ warehouse.create('glue', 'S', comment='This warehouse used by sagemaker to access data') }}
{{ warehouse.create('glue', 'M', comment='This warehouse used by sagemaker to access data') }}

 --creating  warehouse for developer
{{ warehouse.create('developer', 'XS', comment='This warehouse used by onedata developers') }}
