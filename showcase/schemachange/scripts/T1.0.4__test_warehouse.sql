{% import 'modules/database.j2' as database with context -%}
{% import 'modules/schema.j2' as schema with context -%}
{% import 'modules/fileformat.j2' as fileformat with context -%}
{% import 'modules/stage.j2' as stage with context -%}
{% import 'modules/warehouse.j2' as warehouse with context -%}

{{ warehouse.create('worker') }}
{{ warehouse.create('worker', 'M') }}
{{ warehouse.create('worker', 'XL', true) }}
{{ warehouse.create('worker', comment='A worker droid') }}
{{ warehouse.create('worker', tags={'work':'harder'}) }}

{{ warehouse.comment("worker", comment='some comment') }}
-- remove the comment
{{ warehouse.comment("worker", comment="") }}

{{ warehouse.tag("worker", tags={"sometag": 'add a value here'}) }}
-- remove the tag
{{ warehouse.tag("worker", tags={"sometag": none}) }}
{{ warehouse.tag("worker", tags={"sometag": ''}) }}
-- mixed
{{ warehouse.tag("worker", tags={"sometag": 'add a value here', 'another': none, 'tag2': 'value2', 'del2': none}) }}
-- special
{{ warehouse.tag("worker", tags={}) }}

{{ warehouse.grant_usage("worker", role='some_role') }}
{{ warehouse.grant_usage("worker", role='some_role', isdbrole=true) }}
{{ warehouse.revoke_usage("worker", role='some_role') }}
{{ warehouse.revoke_usage("worker", role='some_role', isdbrole=true) }}
