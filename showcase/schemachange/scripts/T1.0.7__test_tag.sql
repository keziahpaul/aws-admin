{% import 'modules/tag.j2' as tag with context -%}

{{ tag.create("db", "schema", "tag1") }}
{{ tag.create("db", "schema", "tag2", 'This is a comment') }}
{{ tag.create("db", "schema", "tag3", values='one value') }}
{{ tag.create("db", "schema", "tag4", values=['one', 'two', 3]) }}
{{ tag.create("db", "schema", "tag5", 'This is a comment', values=['first', 'second']) }}

{{ tag.drop("db", "schema", "tag1") }}

{{ tag.comment("db", "schema", "tag1", "add a comment") }}
-- remove the comment
{{ tag.comment("db", "schema", "tag1") }}

{{ tag.add_allowed_values("db", "schema", "tag1", ["another", "one"]) }}
{{ tag.add_allowed_values("db", "schema", "tag1", "single") }}
-- not valid
{{ tag.add_allowed_values("db", "schema", "tag1", []) }}
-- remove the tag
{{ tag.drop_allowed_values("db", "schema", "tag2", ["more", "than", "one"]) }}
{{ tag.drop_allowed_values("db", "schema", "tag2", "onevalue") }}
{{ tag.drop_allowed_values("db", "schema", "tag2", []) }}

{#
{{ tag.grant_usage("somedb", "somerole") }}
{{ tag.grant_usage("somedb", "somerole", true) }}

{{ tag.revoke_usage("somedb", "somerole") }}
{{ tag.revoke_usage("somedb", "somerole", true) }}
#}
