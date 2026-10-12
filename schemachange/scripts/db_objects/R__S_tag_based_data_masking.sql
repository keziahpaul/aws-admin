{% set in_sf_env = in_sf_env | upper -%}
{% set db = in_sf_env + '_GOVERNANCE_DB' -%}
{% set schema = db + '.COMPLIANCE' -%}
{% set tag_secure_field = schema + '.SECURE_FIELD' -%}
{% set tag_variant_mask = schema + '.VARIANT_MASK' -%}
{% set has_ssa_dbt = ((in_sf_acc_name).lower() in ['group', 'sandbox']) %}

USE ROLE ACCOUNTADMIN;

GRANT APPLY TAG ON ACCOUNT TO ROLE SYSADMIN;

USE ROLE SYSADMIN;
CREATE TAG IF NOT EXISTS {{ tag_secure_field }}
  ALLOWED_VALUES
    'UNMASKED'
  WITH COMMENT = 'This tag is for applying a masking policy to a column based on the type of sensitive data it contains.';
ALTER TAG {{ tag_secure_field }}
  SET ALLOWED_VALUES
    'PI_BUSINESS_NAME', 'PI_CONTACT_NUMBER', 'PI_DOB', 'PI_EMAIL', 'PI_FAX',
    'PI_FREE_TEXT_FIELD', 'PI_FULL_ADDRESS', 'PI_FULL_NAME', 'PI_GENERIC',
    'PI_MULTI', 'PI_NAME', 'PI_PARTIAL_ADDRESS', 'PI_SENSITIVE',
    'PI_SENSITIVE_FINANCIAL', 'PI_USERID',
    -- legacy values for backward compatibility, these values will be phased out in favor of more specific tags
    'PI_BOOLEAN', 'PI_DATE', 'PI_STRING', 'PI_NUMBER', 
    -- allow 'UNMASKED' as a value to indicate that a column should not be masked, even if it contains
    -- sensitive data. This is useful for cases where masking is not desired or necessary.
    'UNMASKED';
ALTER TAG {{ tag_secure_field }} SET PROPAGATE = ON_DEPENDENCY;

/*
  MASKING RULES will apply when the SECURE_FIELD tag is applied to a given typed
  column with one of the following values:
    BOOLEAN -> 'PI_SENSITIVE'
    DATE    -> 'PI_DOB', 'PI_SENSITIVE'
    NUMBER  -> 'PI_SENSITIVE', 'PI_SENSITIVE_FINANCIAL', 'PI_USERID'
    STRING  -> 'PI_BUSINESS_NAME', 'PI_CONTACT_NUMBER', 'PI_EMAIL', 'PI_FAX',
               'PI_FREE_TEXT_FIELD', 'PI_FULL_ADDRESS', 'PI_FULL_NAME',
               'PI_GENERIC', 'PI_MULTI', 'PI_NAME', 'PI_PARTIAL_ADDRESS',
               'PI_SENSITIVE', 'PI_SENSITIVE_FINANCIAL', 'PI_USERID'
    VARIANT -> 'PI_MULTI'
*/

GRANT OWNERSHIP ON TAG {{ tag_secure_field }} TO ROLE SYSADMIN REVOKE CURRENT GRANTS;
GRANT APPLY ON TAG {{ tag_secure_field }} TO ROLE {{ in_sf_env }}_DBT_INTEGRATION_ROLE_S;
{%- if has_ssa_dbt %}
GRANT APPLY ON TAG {{ tag_secure_field }} TO ROLE {{ in_sf_env }}_SSA_DBT_INTEGRATION_ROLE_S;
{%- endif %}

CREATE TAG IF NOT EXISTS {{ tag_variant_mask }}
  ALLOWED_VALUES
    'UNMASKED'
  WITH COMMENT = 'This tag is for applying a masking policy to a column with VARIANT-like data.';
ALTER TAG {{ tag_variant_mask }}
  SET ALLOWED_VALUES
    'TRAVERSE_VALUE_MASK', 'NO_SCHEMA',
    -- allow 'UNMASKED' as a value to indicate that a column should not be masked, even if it contains
    -- sensitive data. This is useful for cases where masking is not desired or necessary.
    'UNMASKED';
ALTER TAG {{ tag_variant_mask }} SET PROPAGATE = ON_DEPENDENCY;
/*
  When a STRING or VARIANT field has a SECURE_FIELD tag value of PI_MULTI,
  masking will be applied based on the value of the VARIANT_MASK tag.
    TRAVERSE_VALUE_MASK -> keep structural keys and apply generic masking to values - default if VARIANT_MASK is not set
    NO_SCHEMA           -> return an object with a meaningless structure
    UNMASKED            -> don't apply masking, for completeness. SECURE_FIELD should be set to UNMASKED

  The column is treated as follows:
    STRING  -> expects a json string which will be masked and returned as a string
    VARIANT -> masked accordingly
*/

GRANT OWNERSHIP ON TAG {{ tag_variant_mask }} TO ROLE SYSADMIN REVOKE CURRENT GRANTS;
GRANT APPLY ON TAG {{ tag_variant_mask }} TO ROLE {{ in_sf_env }}_DBT_INTEGRATION_ROLE_S;
{%- if has_ssa_dbt %}
GRANT APPLY ON TAG {{ tag_variant_mask }} TO ROLE {{ in_sf_env }}_SSA_DBT_INTEGRATION_ROLE_S;
{%- endif %}

-- Determine if the client is allowed access to unmasked data
CREATE OR REPLACE SECURE FUNCTION {{ schema }}.ALLOWED_ROLE(cur_role STRING)
  RETURNS BOOLEAN
  AS
$$
    IS_DATABASE_ROLE_IN_SESSION( 'PI_PUBLIC_DATASHARE_DBROLE' ) 
    OR 
    cur_role IN (
                 '{{ in_sf_env }}_DBT_INTEGRATION_ROLE_S',
{%- if has_ssa_dbt %}
                 '{{ in_sf_env }}_SSA_DBT_INTEGRATION_ROLE_S',
{%- endif %}
{%- if in_sf_env in ('DEV', 'TST') %}
                 '{{ in_sf_env }}_ENGINEER_F',
                 '{{ in_sf_env }}_ALATION_INTEGRATION_ROLE_S',
                 '{{ in_sf_env }}_ANALYST_F',
                 '{{ in_sf_env }}_DATA_STEWARD_F',
                 '{{ in_sf_env }}_DI_ANALYST_F',
                 '{{ in_sf_env }}_GITHUB_INTEGRATION_ROLE_S',
                 '{{ in_sf_env }}_SCIENTIST_F',
{%- endif %}
                 '{{ in_sf_env }}_SUPPORT_F',
                 '{{ in_sf_env }}_TABLEAU_INTEGRATION_ROLE_S',
                 {#- other roles that should have access to unmasked data can be added here #}
                 '{{ in_sf_env }}_CEMP_DB_SCHEMAUS_INTEGRATION_ROLE_S',
                 '{{ in_sf_env }}_DATA_GOVERNANCE_SPECIALIST_F',
                 '{{ in_sf_env }}_DATA_SCIENTIST_PUBLIC_F',
                 '{{ in_sf_env }}_DI_ANALYST_PUBLIC_F',
                 '{{ in_sf_env }}_FIVETRAN_INTEGRATION_ROLE_S',
                 '{{ in_sf_env }}_SAGEMAKER_INTEGRATION_ROLE_S'
                )
$$;

-- Function to mask JSON/VARIANT data
CREATE OR REPLACE SECURE FUNCTION {{ schema }}.MASK_JSON(V VARIANT, VARIANT_MASK STRING DEFAULT NULL)
  RETURNS VARIANT
  LANGUAGE JAVASCRIPT
  COMMENT='Masking Policy function for variant values'
  AS $$
var format;
var traverse = "TRAVERSE_VALUE_MASK";
var schemaless = "NO_SCHEMA";
var default_mask = traverse;

function process_string(str) {
    return "*".repeat(str.length)
}

function mask_value(input) {
    if (typeof input === "string") {
        return process_string(input)
    }
    else if (typeof input === "number") {
        return input < 0 ? -1 : input > 0 ? 1 : 0
    }
    else if (typeof input === "boolean") {
        return null
    }
    return input
}

function traverse_and_mask(input) {
    var masked;
    if (Array.isArray(input)) {
        masked = input.map(traverse_and_mask)
    }
    else if (typeof input === "object" && input != null) {
        masked = {};
        for (var key in input) {
            masked[key] = traverse_and_mask(input[key])
        }
    }
    else {
        masked = mask_value(input)
    }
    return masked
}

format = (typeof VARIANT_MASK === "undefined") ? default_mask : VARIANT_MASK;
if (format === traverse) {
    return traverse_and_mask(V)
}
else if (format === schemaless) {
    if (Array.isArray(V)) {
        return []
    }
    else if (typeof V === "object" && V != null) {
        return {"schema": "masked"}
    }
    else
        return null
}
else {
    return V
}
$$;

-- Masking Policy Functions

/*
Mask Boolean values depending on which role and tag value has been applied
If the val is NULL, then return NULL
If the current role is allowed to view unmasked data, return the value without masking
If the tag value is PI_BOOLEAN, return NULL -- legacy tag, should be treated the same as PI_SENSITIVE
If the tag value is PI_SENSITIVE, return NULL
Else return the value without masking
*/
CREATE OR REPLACE SECURE FUNCTION {{ schema }}.RESTRICTED_VALUE ( val BOOLEAN, cur_role STRING, pi_rule STRING, variant_mask STRING DEFAULT NULL )
  RETURNS BOOLEAN
  COMMENT='Masking Policy function for boolean values'
  AS
$$
IFF(val IS NULL OR {{ schema }}.ALLOWED_ROLE(cur_role), val,
    CASE
    WHEN pi_rule IN ('PI_BOOLEAN', 'PI_SENSITIVE')
        THEN NULL
    ELSE val
    END)
$$;

/*
Mask Date values depending on which role and tag value has been applied
If the val is NULL, then return NULL
If the current role is allowed to view unmasked data, return the value without masking
If the tag value is PI_DATE, adjust the year to be in the range 1900-1904 and keep the month and day the same -- legacy tag, should be treated the same as PI_SENSITIVE
If the tag value is PI_DOB, adjust the year to be in the range 1900-1904 and keep the month and day the same
If the tag value is PI_SENSITIVE, adjust the year to be in the range 1900-1904 and keep the month and day the same
Else return the value without masking
*/
CREATE OR REPLACE SECURE FUNCTION {{ schema }}.RESTRICTED_VALUE ( val DATE, cur_role STRING, pi_rule STRING, variant_mask STRING DEFAULT NULL )
  RETURNS DATE
  COMMENT='Masking Policy function for date values'
  AS
$$
IFF(val IS NULL OR {{ schema }}.ALLOWED_ROLE(cur_role), val,
    CASE
    WHEN pi_rule IN ('PI_DATE', 'PI_DOB', 'PI_SENSITIVE')
        THEN DATEADD('YEAR',
                     IFF((EXTRACT('YEAR', val) % 4 = 0 AND EXTRACT('YEAR', val) % 100 != 0) OR
                         EXTRACT('YEAR', val) % 400 = 0, 1904, 1900) + EXTRACT('YEAR', val) % 4 - EXTRACT('YEAR', val),
                     val)
    ELSE val
    END)
$$;

/*
Mask Number values depending on which role and tag value has been applied
If the val is NULL, then return NULL
If the current role is allowed to view unmasked data, return the value without masking
If the tag value is PI_NUMBER, return the sign of the number (-1, 0, 1) -- legacy tag, should be treated the same as PI_SENSITIVE
If the tag value is PI_SENSITIVE, return the sign of the number (-1, 0, 1)
If the tag value is PI_SENSITIVE_FINANCIAL, return the sign of the number (-1, 0, 1)
If the tag value is PI_USERID, return a hash of the number
Else return the value without masking
*/
CREATE OR REPLACE SECURE FUNCTION {{ schema }}.RESTRICTED_VALUE ( val NUMBER, cur_role STRING, pi_rule STRING, variant_mask STRING DEFAULT NULL )
  RETURNS NUMBER
  COMMENT='Masking Policy function for number values'
  AS
$$
IFF(val IS NULL OR {{ schema }}.ALLOWED_ROLE(cur_role), val,
    CASE
    WHEN pi_rule IN ('PI_NUMBER', 'PI_SENSITIVE', 'PI_SENSITIVE_FINANCIAL')
        THEN SIGN(val)
    WHEN pi_rule = 'PI_USERID'
        THEN HASH(val)
    ELSE val
    END)
$$;

/*
Mask String values depending on which role and tag value has been applied
If the val is NULL, then return NULL
If the current role is allowed to view unmasked data, return the value without masking
If the tag value is PI_BUSINESS_NAME, return the value with all non-space characters replaced by '*'
If the tag value is PI_CONTACT_NUMBER, return the value with all but the last 4 non-space characters replaced by '*'
If the tag value is PI_EMAIL, return a hash of the value as a string with the domain replaced by '.private.org'
If the tag value is PI_FAX, return the value with all but the last 4 non-space characters replaced by '*'
If the tag value is PI_FREE_TEXT_FIELD, return the phrase 'free text field'
If the tag value is PI_FULL_ADDRESS, return the value with all non-space characters replaced by '*'
If the tag value is PI_FULL_NAME, return the value with all non-space characters replaced by '*'
If the tag value is PI_GENERIC, return '*'
If the tag value is PI_NAME, return the value with all non-space characters replaced by '*'
If the tag value is PI_PARTIAL_ADDRESS, return the value with all non-space characters replaced by '*'
If the tag value is PI_SENSITIVE, return the value with all non-space characters replaced by '*'
If the tag value is PI_SENSITIVE_FINANCIAL, return the value with all alphabetic and numeric characters replaced by '0'
If the tag value is PI_STRING, return the value with all non-space characters replaced by '*' -- legacy tag, should be treated the same as PI_SENSITIVE
If the tag value is PI_USERID, return a hash of the value as a string
Else return the value without masking
*/
CREATE OR REPLACE SECURE FUNCTION {{ schema }}.RESTRICTED_VALUE ( val STRING, cur_role STRING, pi_rule STRING, variant_mask STRING DEFAULT NULL )
  RETURNS STRING
  COMMENT='Masking Policy function for string values'
  AS
$$
IFF(val IS NULL OR {{ schema }}.ALLOWED_ROLE(cur_role), val,
    CASE
    WHEN pi_rule IN ('PI_BUSINESS_NAME', 'PI_FULL_ADDRESS', 'PI_FULL_NAME', 'PI_NAME', 'PI_PARTIAL_ADDRESS', 'PI_SENSITIVE', 'PI_STRING')
        THEN REGEXP_REPLACE(val, '[^ ]', '*')
    WHEN pi_rule IN ('PI_CONTACT_NUMBER', 'PI_FAX')
        THEN REVERSE(REGEXP_REPLACE(REVERSE(val), '[^ ]', '*', GREATEST(REGEXP_INSTR(REVERSE(val), '[^ ]', 1, 5), 1)))
    WHEN pi_rule = 'PI_EMAIL'
        THEN ABS(HASH(SPLIT_PART(val, '@', 1)))::STRING || '@' || ABS(HASH(SPLIT_PART(val, '@', -1)))::STRING || '.private.org'
    WHEN pi_rule = 'PI_FREE_TEXT_FIELD'
        THEN 'free text field'
    WHEN pi_rule = 'PI_GENERIC'
        THEN '*'
    WHEN pi_rule = 'PI_SENSITIVE_FINANCIAL'
        THEN REGEXP_REPLACE(val, '[0-9a-zA-Z]', '0')
    WHEN pi_rule = 'PI_USERID'
        THEN HASH(val)::STRING
    WHEN pi_rule = 'PI_MULTI'
        THEN TO_JSON({{ schema }}.MASK_JSON(TRY_PARSE_JSON(val), variant_mask))
    ELSE val
    END)
$$;

/*
Mask Variant/JSON values depending on which role and tag value has been applied
If the val is NULL, then return NULL
If the current role is allowed to view unmasked data, return the value without masking
If the tag value is PI_MULTI, apply the MASK_JSON to mask the JSON object
Else return the value without masking
*/
CREATE OR REPLACE SECURE FUNCTION {{ schema }}.RESTRICTED_VALUE ( val VARIANT, cur_role STRING, pi_rule STRING, variant_mask STRING )
  RETURNS VARIANT
  COMMENT='Masking Policy function for variant values'
  AS
$$
IFF(val IS NULL OR {{ schema }}.ALLOWED_ROLE(cur_role), val,
    CASE
    WHEN pi_rule = 'PI_MULTI'
        THEN {{ schema }}.MASK_JSON(val, variant_mask)
    ELSE val
    END)
$$;

-- Row Access Policies
CREATE ROW ACCESS POLICY IF NOT EXISTS {{ schema }}.EXT_TABLE_ROW_ACCESS_POLICY AS (VALUE VARIANT) 
RETURNS BOOLEAN ->
    {{ schema }}.ALLOWED_ROLE(CURRENT_ROLE())
COMMENT='Row Access Policy for use on external tables'
;

-- Masking Policies
CREATE MASKING POLICY IF NOT EXISTS {{ schema }}.MASKING_BOOLEAN AS (val BOOLEAN)
RETURNS BOOLEAN ->
    {{ schema }}.RESTRICTED_VALUE(
        val,
        CURRENT_ROLE(),
        SYSTEM$GET_TAG_ON_CURRENT_COLUMN('{{ tag_secure_field }}'),
        SYSTEM$GET_TAG_ON_CURRENT_COLUMN('{{ tag_variant_mask }}')
    );

CREATE MASKING POLICY IF NOT EXISTS {{ schema }}.MASKING_DATE AS (val DATE)
RETURNS DATE ->
    {{ schema }}.RESTRICTED_VALUE(
        val,
        CURRENT_ROLE(),
        SYSTEM$GET_TAG_ON_CURRENT_COLUMN('{{ tag_secure_field }}'),
        SYSTEM$GET_TAG_ON_CURRENT_COLUMN('{{ tag_variant_mask }}')
    );

CREATE MASKING POLICY IF NOT EXISTS {{ schema }}.MASKING_NUMBER AS (val NUMBER)
RETURNS NUMBER ->
    {{ schema }}.RESTRICTED_VALUE(
        val,
        CURRENT_ROLE(),
        SYSTEM$GET_TAG_ON_CURRENT_COLUMN('{{ tag_secure_field }}'),
        SYSTEM$GET_TAG_ON_CURRENT_COLUMN('{{ tag_variant_mask }}')
    );

CREATE MASKING POLICY IF NOT EXISTS {{ schema }}.MASKING_STRING AS (val STRING)
RETURNS STRING ->
    {{ schema }}.RESTRICTED_VALUE(
        val,
        CURRENT_ROLE(),
        SYSTEM$GET_TAG_ON_CURRENT_COLUMN('{{ tag_secure_field }}'),
        SYSTEM$GET_TAG_ON_CURRENT_COLUMN('{{ tag_variant_mask }}')
    );

CREATE MASKING POLICY IF NOT EXISTS {{ schema }}.MASKING_VARIANT AS (val VARIANT)
RETURNS VARIANT ->
    {{ schema }}.RESTRICTED_VALUE(
        val,
        CURRENT_ROLE(),
        SYSTEM$GET_TAG_ON_CURRENT_COLUMN('{{ tag_secure_field }}'),
        SYSTEM$GET_TAG_ON_CURRENT_COLUMN('{{ tag_variant_mask }}')
    );

USE ROLE ACCOUNTADMIN;
ALTER TAG {{ tag_secure_field }}
  SET
    MASKING POLICY {{ schema }}.MASKING_BOOLEAN,
    MASKING POLICY {{ schema }}.MASKING_DATE,
    MASKING POLICY {{ schema }}.MASKING_NUMBER,
    MASKING POLICY {{ schema }}.MASKING_STRING,
    MASKING POLICY {{ schema }}.MASKING_VARIANT
;

USE ROLE SYSADMIN;
/*
For use in dbt pre_hook to remove tags from columns. This procedure will remove all tags from a given table, so use with caution.
The intended use is to call this procedure in a dbt pre-hook for any models that have tag-based masking, so the model can be put
into a clean state before attempting to apply tags and masking policies.

Example usage in dbt_project.yml:
  pre_hook="CALL <<env_var('DBT_GOVERNANCE_DB')>>.<<env_var('DBT_GOVERNANCE_SCHEMA')>>.STRIP_COLUMN_TAGS('<< this.database >>', '<< this.schema >>', '<< this.identifier >>')"

Note: angle brackets have been used in place of curly braces in the example usage to avoid confusion with the Jinja templating syntax.
*/
CREATE OR REPLACE PROCEDURE {{ schema }}.STRIP_COLUMN_TAGS(database STRING, schema STRING, table_name STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'strip_tags'
EXECUTE AS CALLER
AS
$$
def strip_tags(session, database, schema, table_name):
    result = session.sql("""
        SELECT DATABASE_NAME
        FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASES
        WHERE DATABASE_NAME ILIKE ? AND DELETED IS NULL
        """, params=[database]).collect()
    if not result:
        return 'Missing Database'
    database = f'"{result[0]["DATABASE_NAME"]}"'

    result = session.sql(f"""
        SELECT TABLE_SCHEMA, TABLE_NAME
        FROM {database}.INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA ILIKE ? AND TABLE_NAME ILIKE ?
        """, params=[schema, table_name]).collect()
    if not result:
        return 'Missing Table'
    table_name = f'{database}."{result[0]["TABLE_SCHEMA"]}"."{result[0]["TABLE_NAME"]}"'

    col_list = session.sql(f"""
        WITH columns AS (
            SELECT COLUMN_NAME, LISTAGG(TAG_DATABASE || '.' || TAG_SCHEMA || '.' || TAG_NAME, ', ') WITHIN GROUP (ORDER BY TAG_NAME) AS tag_list
            FROM TABLE({database}.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(?, 'table'))
            GROUP BY COLUMN_NAME
        )
        SELECT LISTAGG('COLUMN "' || COLUMN_NAME || '" UNSET TAG ' || tag_list, ',\n  ') WITHIN GROUP (ORDER BY COLUMN_NAME) AS col_list
        FROM columns
        """, params=[table_name]).collect()[0]['COL_LIST']

    if not col_list:
        return 'No Tags Found'

    session.sql(f'ALTER TABLE {table_name} ALTER\n  {col_list};').collect()
    return 'OK'
$$;
