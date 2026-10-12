{% import 'modules/database.j2' as database with context -%}
{% import 'modules/role.j2' as role with context -%}
{% import 'modules/dbrole.j2' as dbrole with context -%}

{{ database.create("raw") }}
{{ database.create("staging", "this is the stage database") }}
{{ database.create("production", tags={"somepi": 'in here',"and":"another", "missing":"", "none":none}) }}
{{ database.create("curate", "this is the stage database", {"another": 'tag here'}) }}
-- special
{{ database.create("curate", ' ', {}) }}

{{ database.create_from_share("local", "PRD_SOURCE") }}

{{ database.drop("raw") }}
{{ database.use("staging") }}

{{ database.comment("somedb", "add a comment") }}
-- remove the comment
{{ database.comment("somedb") }}

{{ database.tag("somedb", {"sometag": 'add a value here'}) }}
-- remove the tag
{{ database.tag("somedb", {"sometag": none}) }}
{{ database.tag("somedb", {"sometag": ''}) }}
-- mixed
{{ database.tag("somedb", {"sometag": 'add a value here', 'another': none, 'tag2': 'value2', 'del2': none}) }}
-- special
{{ database.tag("somedb", {}) }}

{{ database.grant_usage("somedb", role.name("somerole", "F")) }}
{{ database.grant_usage("somedb", dbrole.name("somerole", "S"), true) }}

{{ database.revoke_usage("somedb", role.name("somerole", "F")) }}
{{ database.revoke_usage("somedb", dbrole.name("somerole", "S", database.name("somedb")), true) }}
