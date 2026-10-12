-- Create or replace notification integration

{% if (in_sf_env.lower() == 'dev') or (in_sf_env.lower() == 'prd') %}
    {% if in_sf_env.lower() == 'dev' %}
        {% set email_address = params_dict['dev_onedata_alert_slack_email'] %}
    {% elif in_sf_env.lower() == 'prd' %}
        {% set email_address = params_dict['prd_onedata_alert_slack_email'] %}
    {% endif %}

    -- Create or replace alert
    CREATE OR REPLACE ALERT {{ in_sf_env }}_LOGGING.public.timed_out_long_running_query_alerts
    WAREHOUSE = {{ in_sf_env }}_developer_xs_wh
    SCHEDULE = 'USING CRON 0 */6 * * * UTC'
    IF (EXISTS (
        SELECT QUERY_ID, DATABASE_NAME, USER_NAME
        FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
        WHERE ERROR_CODE::varchar = '000630' -- timeout error code.
            AND END_TIME >= DATEADD('hour', -6, CURRENT_TIMESTAMP())
    ))
    THEN
    CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
    SNOWFLAKE.NOTIFICATION.TEXT_HTML(
        (SELECT
        CONCAT(
            '<p>Hi Team,<br>',
            'Following ',
            CASE WHEN COUNT(*) > 1 THEN 'queries' ELSE 'query' END, 
            ' timed out in the last 6 hours in {{ in_sf_env }} {{ in_sf_acc_name }} Snowflake:</p>',
            LISTAGG(
            CONCAT(
                '<p>',
                '<b>Account Name:</b> {{ in_sf_acc_name }} <br>',
                '<b>Database Name:</b> ', nvl(DATABASE_NAME,'Unknown'), '<br>',
                '<b>User Name:</b> ', nvl(USER_NAME,'Unknown'), '<br>',
                '<b>QUERY_ID:</b> ', nvl(QUERY_ID,'Unknown'), '<br>',
                '</p><br>'
            )) WITHIN GROUP (ORDER BY DATABASE_NAME,USER_NAME,QUERY_ID)
        )
        FROM TABLE(RESULT_SCAN(SNOWFLAKE.ALERT.GET_CONDITION_QUERY_UUID()))
        )
    ),
    SNOWFLAKE.NOTIFICATION.EMAIL_INTEGRATION_CONFIG(
        '{{ in_sf_env }}_slack_alert_integration',
        '{{ in_sf_env }} {{ in_sf_acc_name }} - Timed Out Long query alerts',
        ARRAY_CONSTRUCT({{ email_address }})
    )
    );

    -- Alter alert to start it
    ALTER ALERT {{ in_sf_env }}_LOGGING.public.timed_out_long_running_query_alerts RESUME;

    -- Grant access
    GRANT EXECUTE ALERT ON ACCOUNT TO ROLE {{in_sf_env}}_GITHUB_INTEGRATION_ROLE_S;
{%else%}
  select 1;
{%endif%}
