{% import 'modules/database.j2' as database with context -%}
{% import 'modules/schema.j2' as schema with context -%}
{% import 'modules/fileformat.j2' as fileformat with context -%}
{% import 'modules/stage.j2' as stage with context -%}

SELECT '{{ stage.name("somedb", "some_schema", "reports") }}' as name;
SELECT '{{ stage.legacy_name("somedb", "some_schema", "reports") }}' as legacy_name;

{{ stage.create_s3("somedb", "some_schema", "reports", 'some_integration', 'some_bucket', 'some_prefix/') }}
{{ stage.create_s3("somedb", "some_schema", "reports", 'some_integration', 'some_bucket', 'some_prefix/', kms_key_id='special_kms') }}
{{ stage.create_s3("somedb", "some_schema", "reports", 'some_integration', 'some_bucket', 'some_prefix/', kms_key_id='special_kms', comment='some comment') }}
{{ stage.create_s3("somedb", "some_schema", "reports", 'some_integration', 'some_bucket', 'some_prefix/', comment="some comment here") }}
{{ stage.create_s3("somedb", "some_schema", "reports", 'some_integration', 'some_bucket', 'some_prefix/', tags={"some": "tag_value"}) }}
{{ stage.create_s3("somedb", "some_schema", "reports", 'some_integration', 'some_bucket', 'some_prefix/', comment="some comment here", tags={"some": "tag_value"}) }}
-- logging ?
{{ stage.create_s3("somedb", "some_schema", "logging", 'some_integration', 'some_bucket', 'some_prefix/') }}

{{ stage.drop("somedb", "some_schema", "reports") }}

{{ stage.comment("somedb", "some_schema", "reports", 'some comment') }}
-- remove the comment
{{ stage.comment("somedb", "some_schema", "reports") }}

{{ stage.tag("somedb", "some_schema", "reports", {"sometag": 'add a value here'}) }}
-- remove the tag
{{ stage.tag("somedb", "some_schema", "reports", {"sometag": none}) }}
{{ stage.tag("somedb", "some_schema", "reports", {"sometag": ''}) }}
-- mixed
{{ stage.tag("somedb", "some_schema", "reports", {"sometag": 'add a value here', 'another': none, 'tag2': 'value2', 'del2': none}) }}
-- special
{{ stage.tag("somedb", "some_schema", "reports", {}) }}

{{ stage.grant_usage("somedb", "some_schema", "reports", 'some_role') }}
{{ stage.grant_usage("somedb", "some_schema", "reports", 'some_role', true) }}
{{ stage.revoke_usage("somedb", "some_schema", "reports", 'some_role') }}
{{ stage.revoke_usage("somedb", "some_schema", "reports", 'some_role', true) }}
