{% import 'modules/role.j2' as role with context -%}

{{ role.create("the_role", "S") }}
{{ role.create("the_role", "A") }}
{{ role.create("the_role", "F") }}
{{ role.create("client", "F", "this is the client role") }}
{{ role.create("runner", "F", tags={"somepi": 'in here',"and":"another", "missing":"", "none":none}) }}
{{ role.create("all_in", "S", "this is the allin role", {"another": 'tag here'}) }}

{{ role.drop("the_role", "S") }}

{{ role.use("the_role", "S") }}

{{ role.comment("the_role", "S", "add a comment") }}
-- remove the comment
{{ role.comment("the_role", "S") }}

{{ role.tag("the_role", "S", {"sometag": 'add a value here'}) }}
-- remove the tag
{{ role.tag("the_role", "S", {"sometag": none}) }}
{{ role.tag("the_role", "S", {"sometag": ''}) }}
-- mixed
{{ role.tag("the_role", "S", {"sometag": 'add a value here', 'another': none, 'tag2': 'value2', 'del2': none}) }}
-- special
{{ role.tag("the_role", "S", {}) }}

{#
{{ role.grant_usage("somedb", "somerole") }}
{{ role.grant_usage("somedb", "somerole", true) }}

{{ role.revoke_usage("somedb", "somerole") }}
{{ role.revoke_usage("somedb", "somerole", true) }}
#}
