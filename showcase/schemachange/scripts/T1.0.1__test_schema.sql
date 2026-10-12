{% import 'modules/database.j2' as database with context -%}
{% import 'modules/schema.j2' as schema with context -%}

{{ schema.create('raw', 'schema') }}
{{ schema.create('raw', 'schema', 'this is a comment') }}
{{ schema.create('raw', 'schema', tags={'tag1':'value'}) }}
{{ schema.create('raw', 'schema', 'this is a comment', {'tag1':'value'}) }}

{{ schema.drop('raw', 'schema') }}
{{ schema.drop('raw', 'schema_all', true) }}
{{ schema.use('raw', 'schema') }}

{{ schema.comment("somedb", "some_schema", "add a comment") }}
-- remove the comment
{{ schema.comment("somedb", "some_schema") }}

{{ schema.tag("somedb", "some_schema", {"sometag": 'add a value here'}) }}
-- remove the tag
{{ schema.tag("somedb", "some_schema", {"sometag": none}) }}
{{ schema.tag("somedb", "some_schema", {"sometag": ''}) }}
-- mixed
{{ schema.tag("somedb", "some_schema", {"sometag": 'add a value here', 'another': none, 'tag2': 'value2', 'del2': none}) }}
-- special
{{ schema.tag("somedb", "some_schema", {}) }}

{{ schema.grant_usage("somedb", "some_schema", "somerole") }}
{{ schema.grant_usage("somedb", "some_schema", "somerole", true) }}

{{ schema.revoke_usage("somedb", "some_schema", "somerole") }}
{{ schema.revoke_usage("somedb", "some_schema", "somerole", true) }}
