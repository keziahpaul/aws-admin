{% import 'modules/database.j2' as database with context -%}
{% import 'modules/schema.j2' as schema with context -%}
{% import 'modules/fileformat.j2' as fileformat with context -%}

SELECT '{{ fileformat.name("somedb", "some_schema", "reports") }}' as name;
SELECT '{{ fileformat.legacy_name("somedb", "some_schema", "reports") }}' as legacy_name;

{{ fileformat.create("somedb", "some_schema", "reports", "csv") }}
{{ fileformat.create("somedb", "some_schema", "reports", "csv", comment='This is a csv FF') }}
{{ fileformat.create("somedb", "some_schema", "reports", "json", comment='This is a json FF') }}
{{ fileformat.create("somedb", "some_schema", "reports", "parquet", comment='This is a parquet FF') }}

{{ fileformat.drop("somedb", "some_schema", "reports") }}
{{ fileformat.comment("somedb", "some_schema", "reports", 'change of comment') }}

{{ fileformat.grant_usage("somedb", "some_schema", "reports", 'some_role') }}
{{ fileformat.grant_usage("somedb", "some_schema", "reports", 'some_role', true) }}
{{ fileformat.revoke_usage("somedb", "some_schema", "reports", 'some_role') }}
{{ fileformat.revoke_usage("somedb", "some_schema", "reports", 'some_role', true) }}
