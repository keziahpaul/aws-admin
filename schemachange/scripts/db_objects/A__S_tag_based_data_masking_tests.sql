{% set in_sf_env = in_sf_env | upper -%}
{% set db = in_sf_env + "_GOVERNANCE_DB" -%}
{% set schema = db + ".COMPLIANCE" -%}
{% set has_ssa_dbt = ((in_sf_acc_name).lower() in ['group', 'sandbox']) %}

{% set all_allowed_roles -%}
    {{ in_sf_env }}_DBT_INTEGRATION_ROLE_S
{%- if has_ssa_dbt %}
    {{ in_sf_env }}_SSA_DBT_INTEGRATION_ROLE_S
{%- endif %}
{%- if in_sf_env in ('DEV', 'TST') %}
    {{ in_sf_env }}_ENGINEER_F
    {{ in_sf_env }}_ALATION_INTEGRATION_ROLE_S
    {{ in_sf_env }}_ANALYST_F
    {{ in_sf_env }}_DATA_STEWARD_F
    {{ in_sf_env }}_DI_ANALYST_F
    {{ in_sf_env }}_GITHUB_INTEGRATION_ROLE_S
    {{ in_sf_env }}_SCIENTIST_F
{%- endif %}
    {{ in_sf_env }}_SUPPORT_F
    {{ in_sf_env }}_TABLEAU_INTEGRATION_ROLE_S
    {#- other roles that should have access to unmasked data can be added here #}
    {{ in_sf_env }}_CEMP_DB_SCHEMAUS_INTEGRATION_ROLE_S
    {{ in_sf_env }}_DATA_GOVERNANCE_SPECIALIST_F
    {{ in_sf_env }}_DATA_SCIENTIST_PUBLIC_F
    {{ in_sf_env }}_DI_ANALYST_PUBLIC_F
    {{ in_sf_env }}_FIVETRAN_INTEGRATION_ROLE_S
    {{ in_sf_env }}_SAGEMAKER_INTEGRATION_ROLE_S
{%- endset -%}
{% set all_allowed_roles = all_allowed_roles.splitlines() | map('trim') | list -%}

{# this is a known role which is allowed to see data -#}
{% set allowed_role = all_allowed_roles[0] -%}
{# create a fictitious role which is not allowed to see data -#}
{% set disallowed_role = "NOT_" + allowed_role -%}

WITH TEST_ALLOWED_ROLE AS PROCEDURE()
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
DECLARE
    bool_result BOOLEAN;
    assert_fail_1 EXCEPTION(-20001, 'Disallowed role did not return false');
BEGIN
{%- for role in all_allowed_roles %}
    DECLARE
        assert_fail_2 EXCEPTION(-20002, 'Allowed role {{ role }} did not return true');
    BEGIN
        bool_result := {{ schema }}.ALLOWED_ROLE('{{ role }}');
        IF (bool_result IS DISTINCT FROM TRUE) THEN
            RAISE assert_fail_2;
        END IF;
    END;
{%- endfor %}

    bool_result := {{ schema }}.ALLOWED_ROLE('{{ disallowed_role }}');
    IF (bool_result IS DISTINCT FROM FALSE) THEN
        RAISE assert_fail_1;
    END IF;

    RETURN TRUE;
END;
$$
CALL TEST_ALLOWED_ROLE();

WITH TEST_ALLOWED_DATABASE_ROLE AS PROCEDURE()
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
DECLARE
    bool_result BOOLEAN;
    cur_role STRING DEFAULT CURRENT_ROLE();
    assert_fail_1 EXCEPTION(-20071, 'Database role in session did not return true');
    assert_fail_2 EXCEPTION(-20072, 'Database role not in session did not return false');
BEGIN
    bool_result := IS_DATABASE_ROLE_IN_SESSION( 'PI_PUBLIC_DATASHARE_DBROLE' );

    -- current role already has this grant
    IF (bool_result = TRUE) THEN
        -- Revoke the database role so IS_DATABASE_ROLE_IN_SESSION returns FALSE
        EXECUTE IMMEDIATE 'REVOKE DATABASE ROLE {{ db }}.PI_PUBLIC_DATASHARE_DBROLE FROM ROLE ' || cur_role;

        bool_result := {{ schema }}.ALLOWED_ROLE('{{ disallowed_role }}');

        -- Put back the grant
        EXECUTE IMMEDIATE 'GRANT DATABASE ROLE {{ db }}.PI_PUBLIC_DATASHARE_DBROLE TO ROLE ' || cur_role;

        IF (bool_result IS DISTINCT FROM FALSE) THEN
            RAISE assert_fail_2;
        END IF;

        bool_result := {{ schema }}.ALLOWED_ROLE('{{ disallowed_role }}');
        IF (bool_result IS DISTINCT FROM TRUE) THEN
            RAISE assert_fail_1;
        END IF;
    ELSE
        -- Grant the database role so IS_DATABASE_ROLE_IN_SESSION returns TRUE
        EXECUTE IMMEDIATE 'GRANT DATABASE ROLE {{ db }}.PI_PUBLIC_DATASHARE_DBROLE TO ROLE ' || cur_role;

        bool_result := {{ schema }}.ALLOWED_ROLE('{{ disallowed_role }}');

        -- Remove the grant
        EXECUTE IMMEDIATE 'REVOKE DATABASE ROLE {{ db }}.PI_PUBLIC_DATASHARE_DBROLE FROM ROLE ' || cur_role;

        IF (bool_result IS DISTINCT FROM TRUE) THEN
            RAISE assert_fail_1;
        END IF;

        bool_result := {{ schema }}.ALLOWED_ROLE('{{ disallowed_role }}');
        IF (bool_result IS DISTINCT FROM FALSE) THEN
            RAISE assert_fail_2;
        END IF;
    END IF;

    RETURN TRUE;
END;
$$
CALL TEST_ALLOWED_DATABASE_ROLE();

WITH TEST_MASK_JSON AS PROCEDURE()
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
DECLARE
    var_result VARIANT;
    var_data VARIANT DEFAULT PARSE_JSON('{"key1": "value1", "key2": 123, "key3": true, "key4": null, "key5": {"nestedKey1": "nestedValue1"}, "key6": [1, "two", false]}');
    traverse_data VARIANT DEFAULT PARSE_JSON('{"key1": "******", "key2": 1, "key3": null, "key4": null, "key5": {"nestedKey1": "************"}, "key6": [1, "***", null]}');
    schemaless_object_data VARIANT DEFAULT PARSE_JSON('{"schema": "masked"}');
    schemaless_array_data VARIANT DEFAULT PARSE_JSON('[]');
    assert_fail_1 EXCEPTION(-20011, 'Default masking did not return appropriately masked data');
    assert_fail_2 EXCEPTION(-20012, 'TRAVERSE_VALUE_MASK masking did not return appropriately masked data');
    assert_fail_3 EXCEPTION(-20013, 'NO_SCHEMA masking did not return appropriately masked data');
    assert_fail_4 EXCEPTION(-20014, 'UNMASKED masking did not return unmasked data');
BEGIN
    var_result := {{ schema }}.MASK_JSON(var_data);
    IF (var_result IS DISTINCT FROM traverse_data) THEN
        RAISE assert_fail_1;
    END IF;

    var_result := {{ schema }}.MASK_JSON(var_data, 'TRAVERSE_VALUE_MASK');
    IF (var_result IS DISTINCT FROM traverse_data) THEN
        RAISE assert_fail_2;
    END IF;

    var_result := {{ schema }}.MASK_JSON(var_data, 'NO_SCHEMA');
    IF (var_result IS DISTINCT FROM schemaless_object_data) THEN
        RAISE assert_fail_3;
    END IF;

    var_result := {{ schema }}.MASK_JSON(GET(var_data, 'key6'), 'NO_SCHEMA');
    IF (var_result IS DISTINCT FROM schemaless_array_data) THEN
        RAISE assert_fail_3;
    END IF;

    var_result := {{ schema }}.MASK_JSON(var_data, 'UNMASKED');
    IF (var_result IS DISTINCT FROM var_data) THEN
        RAISE assert_fail_4;
    END IF;

    RETURN TRUE;
END;
$$
CALL TEST_MASK_JSON();

WITH TEST_RESTRICTED_VALUE_BOOLEAN AS PROCEDURE()
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
DECLARE
    var_result BOOLEAN;
    var_test BOOLEAN;
    assert_fail_1 EXCEPTION(-20021, 'Unmasked boolean did not match');
    assert_fail_2 EXCEPTION(-20022, 'Masked boolean did not match expected value');
BEGIN
{%- for test_val in ('TRUE', 'FALSE') %}
    var_test := {{ test_val }};
    {%- for pi_rule in ('PI_BOOLEAN', 'PI_SENSITIVE') %}

    var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ allowed_role }}', '{{ pi_rule }}', NULL);
    IF (var_result IS DISTINCT FROM var_test) THEN
        RAISE assert_fail_1;
    END IF;

    var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ disallowed_role }}', '{{ pi_rule }}', NULL);
    IF (var_result IS NOT NULL) THEN
        RAISE assert_fail_2;
    END IF;
    {%- endfor %}

    {%- for role in (allowed_role, disallowed_role) %}

    DECLARE
        assert_fail_3 EXCEPTION(-20023, 'Unmasked boolean did not match for role {{ role }} value {{ test_val }}');
    BEGIN
        var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ role }}', 'UNMASKED', NULL);
        IF (var_result IS DISTINCT FROM var_test) THEN
            RAISE assert_fail_3;
        END IF;
    END;
    {%- endfor %}
{% endfor %}
    RETURN TRUE;
END;
$$
CALL TEST_RESTRICTED_VALUE_BOOLEAN();

WITH TEST_RESTRICTED_VALUE_DATE AS PROCEDURE()
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
DECLARE
    var_result DATE;
    var_test DATE;
BEGIN
{%- for test_val in ('1990-12-31', '2000-01-01', '2000-02-29', '2004-02-29', '2023-02-28') %}
    var_test := DATE '{{ test_val }}';
    {%- for pi_rule in ('PI_DATE', 'PI_DOB', 'PI_SENSITIVE') %}

    DECLARE
        assert_fail_1 EXCEPTION(-20031, 'Unmasked date did not match for rule {{ pi_rule }} value {{ test_val }}');
        assert_fail_2 EXCEPTION(-20032, 'Masked date did not match expected value for rule {{ pi_rule }} value {{ test_val }}');
    BEGIN
        var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ allowed_role }}', '{{ pi_rule }}', NULL);
        IF (var_result IS DISTINCT FROM var_test) THEN
            RAISE assert_fail_1;
        END IF;

        var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ disallowed_role }}', '{{ pi_rule }}', NULL);
        IF (var_result IS NOT DISTINCT FROM var_test) THEN
            RAISE assert_fail_2;
        END IF;
    END;
    {%- endfor %}

    {%- for role in (allowed_role, disallowed_role) %}

    DECLARE
        assert_fail_3 EXCEPTION(-20033, 'Unmasked number did not match for role {{ role }} value {{ test_val }}');
    BEGIN
        var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ role }}', 'UNMASKED', NULL);
        IF (var_result IS DISTINCT FROM var_test) THEN
            RAISE assert_fail_3;
        END IF;
    END;
    {%- endfor %}
{% endfor %}
    RETURN TRUE;
END;
$$
CALL TEST_RESTRICTED_VALUE_DATE();

WITH TEST_RESTRICTED_VALUE_NUMBER AS PROCEDURE()
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
BEGIN
{%- for test_val in (123, -456, 1.23, -4.56) %}
    {%- for pi_rule in ('PI_NUMBER', 'PI_SENSITIVE', 'PI_SENSITIVE_FINANCIAL', 'PI_USERID') %}

    DECLARE
        assert_fail_1 EXCEPTION(-20041, 'Unmasked number did not match for rule {{ pi_rule }} value {{ test_val }}');
        assert_fail_2 EXCEPTION(-20042, 'Masked number did not match expected value for rule {{ pi_rule }} value {{ test_val }}');
    BEGIN
        IF ({{ schema }}.RESTRICTED_VALUE({{ test_val }}, '{{ allowed_role }}', '{{ pi_rule }}', NULL) IS DISTINCT FROM {{ test_val }}) THEN
            RAISE assert_fail_1;
        END IF;

        IF ({{ schema }}.RESTRICTED_VALUE({{ test_val }}, '{{ disallowed_role }}', '{{ pi_rule }}', NULL) IS NOT DISTINCT FROM {{ test_val }}) THEN
            RAISE assert_fail_2;
        END IF;
    END;
    {%- endfor %}

    {%- for role in (allowed_role, disallowed_role) %}

    DECLARE
        assert_fail_3 EXCEPTION(-20043, 'Unmasked number did not match for role {{ role }} value {{ test_val }}');
    BEGIN
        IF ({{ schema }}.RESTRICTED_VALUE({{ test_val }}, '{{ role }}', 'UNMASKED', NULL) IS DISTINCT FROM {{ test_val }}) THEN
            RAISE assert_fail_3;
        END IF;
    END;
    {%- endfor %}
{% endfor %}
    RETURN TRUE;
END;
$$
CALL TEST_RESTRICTED_VALUE_NUMBER();

WITH TEST_RESTRICTED_VALUE_STRING AS PROCEDURE()
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
DECLARE
    var_result STRING;
    var_test STRING;
BEGIN
{%- for test_val in ('hello', 'WORLD', '$1,234,567', '+61 13 TAXI', 'someone@gmail.com') %}
    var_test := '{{ test_val }}';
    {%- for pi_rule in ('PI_BUSINESS_NAME', 'PI_CONTACT_NUMBER', 'PI_EMAIL', 'PI_FAX', 'PI_FREE_TEXT_FIELD', 'PI_FULL_ADDRESS', 'PI_FULL_NAME', 'PI_GENERIC', 'PI_NAME', 'PI_PARTIAL_ADDRESS', 'PI_SENSITIVE', 'PI_SENSITIVE_FINANCIAL', 'PI_STRING', 'PI_USERID') %}

    DECLARE
        assert_fail_1 EXCEPTION(-20051, 'Unmasked string did not match for rule {{ pi_rule }} value "{{ test_val }}"');
        assert_fail_2 EXCEPTION(-20052, 'Masked string did not match expected value for rule {{ pi_rule }} value "{{ test_val }}"');
    BEGIN
        var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ allowed_role }}', '{{ pi_rule }}', NULL);
        IF (var_result IS DISTINCT FROM var_test) THEN
            RAISE assert_fail_1;
        END IF;

        var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ disallowed_role }}', '{{ pi_rule }}', NULL);
        IF (var_result IS NOT DISTINCT FROM var_test) THEN
            RAISE assert_fail_2;
        END IF;
    END;
    {%- endfor %}

    {%- for role in (allowed_role, disallowed_role) %}

    DECLARE
        assert_fail_3 EXCEPTION(-20053, 'Unmasked string did not match for role {{ role }} value "{{ test_val }}"');
    BEGIN
        var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ role }}', 'UNMASKED', NULL);
        IF (var_result IS DISTINCT FROM var_test) THEN
            RAISE assert_fail_3;
        END IF;
    END;
    {%- endfor %}
{% endfor %}
    var_test := '{"key1": "value1", "key2": 123, "key3": true, "key4": null, "key5": {"nestedKey1": "nestedValue1"}, "key6": [1, "two", false]}';

    DECLARE
        assert_fail_4 EXCEPTION(-20054, 'Unmasked string did not match for rule PI_MULTI');
        assert_fail_5 EXCEPTION(-20055, 'Masked string did not match expected value for rule PI_MULTI');
    BEGIN
        var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ allowed_role }}', 'PI_MULTI', NULL);
        IF (var_result IS DISTINCT FROM var_test) THEN
            RAISE assert_fail_4;
        END IF;

        var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ disallowed_role }}', 'PI_MULTI', NULL);
        IF (var_result IS NOT DISTINCT FROM var_test) THEN
            RAISE assert_fail_5;
        END IF;
    END;

    RETURN TRUE;
END;
$$
CALL TEST_RESTRICTED_VALUE_STRING();

WITH TEST_RESTRICTED_VALUE_VARIANT AS PROCEDURE()
RETURNS BOOLEAN
LANGUAGE SQL
AS
$$
DECLARE
    var_result VARIANT;
    var_test VARIANT DEFAULT PARSE_JSON('{"key1": "value1", "key2": 123, "key3": true, "key4": null, "key5": {"nestedKey1": "nestedValue1"}, "key6": [1, "two", false]}');
    assert_fail_1 EXCEPTION(-20061, 'Unmasked variant did not match');
    assert_fail_2 EXCEPTION(-20062, 'Masked variant did not match expected value');
BEGIN
    var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ allowed_role }}', 'PI_MULTI', NULL);
    IF (var_result IS DISTINCT FROM var_test) THEN
        RAISE assert_fail_1;
    END IF;

    var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ disallowed_role }}', 'PI_MULTI', NULL);
    IF (var_result IS NOT DISTINCT FROM var_test) THEN
        RAISE assert_fail_2;
    END IF;

    {%- for role in (allowed_role, disallowed_role) %}

    DECLARE
        assert_fail_3 EXCEPTION(-20063, 'Unmasked variant did not match for role {{ role }}');
    BEGIN
        var_result := {{ schema }}.RESTRICTED_VALUE(var_test, '{{ role }}', 'UNMASKED', NULL);
        IF (var_result IS DISTINCT FROM var_test) THEN
            RAISE assert_fail_3;
        END IF;
    END;
    {%- endfor %}

    RETURN TRUE;
END;
$$
CALL TEST_RESTRICTED_VALUE_VARIANT();
