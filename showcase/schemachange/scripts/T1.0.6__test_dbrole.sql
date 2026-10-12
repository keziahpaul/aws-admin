{% import 'modules/dbrole.j2' as dbrole with context -%}

{{ dbrole.create("the_role", "S") }}
{{ dbrole.create("the_role", "A") }}
{{ dbrole.create("the_role", "A", "otherdb") }}
{{ dbrole.create("client", "A", comment="this is the client role") }}
{{ dbrole.create("runner", "A", tags={"somepi": 'in here',"and":"another", "missing":"", "none":none}) }}
{{ dbrole.create("all_in", "S", "otherdb", "this is the allin role", {"another": 'tag here'}) }}

{{ dbrole.drop("the_role", "S") }}
{{ dbrole.drop("all_in", "S", "OTHERDB") }}

{{ dbrole.comment("the_role", "S", comment="add a comment") }}
{{ dbrole.comment("allin", "S", "OTHERDB", "change the comment") }}
-- remove the comment
{{ dbrole.comment("the_role", "S") }}
{{ dbrole.comment("allin", "S", "OTHERDB") }}

{{ dbrole.tag("the_role", "S", tags={"sometag": 'add a value here'}) }}
-- remove the tag
{{ dbrole.tag("the_role", "S", tags={"sometag": none}) }}
{{ dbrole.tag("all_in", "S", "OTHERDB", {"sometag": ''}) }}
-- mixed
{{ dbrole.tag("the_role", "S", tags={"sometag": 'add a value here', 'another': none, 'tag2': 'value2', 'del2': none}) }}
-- special
{{ dbrole.tag("the_role", "S", tags={}) }}

{#
{{ dbrole.grant_usage("somedb", "somerole") }}
{{ dbrole.grant_usage("somedb", "somerole", true) }}

{{ dbrole.revoke_usage("somedb", "somerole") }}
{{ dbrole.revoke_usage("somedb", "somerole", true) }}
#}
