-- Create or replace notification integration
CREATE OR REPLACE NOTIFICATION INTEGRATION {{ in_sf_env }}_slack_alert_integration
    TYPE = EMAIL
    ENABLED = TRUE;

-- Create or replace alert
CREATE OR REPLACE ALERT {{ in_sf_env }}_LOGGING.public.security_alerts_from_trust_center
  WAREHOUSE = {{ in_sf_env }}_developer_xs_wh
  SCHEDULE = 'USING CRON 0 18 * * * UTC'
  IF (EXISTS (
    SELECT SEVERITY, TOTAL_AT_RISK_COUNT, SCANNER_NAME, START_TIMESTAMP, SUGGESTED_ACTION
    FROM SNOWFLAKE.TRUST_CENTER.FINDINGS
    WHERE START_TIMESTAMP >= DATEADD(DAY, -1, CURRENT_TIMESTAMP)
      AND (SEVERITY IN ('HIGH', 'CRITICAL') OR SCANNER_ID = 'SECURITY_ESSENTIALS_CIS3_1')
      AND SCANNER_ID != 'SECURITY_ESSENTIALS_CIS1_4'
      AND TOTAL_AT_RISK_COUNT > 0
  ))
  THEN
CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
  SNOWFLAKE.NOTIFICATION.TEXT_HTML(
    (SELECT
      CONCAT(
        '<p>Hi Team,<br>',
        'There ',
        CASE WHEN COUNT(DISTINCT SEVERITY) > 1 THEN 'are ' ELSE 'is a ' END,
        LISTAGG(DISTINCT SEVERITY, ' and ') WITHIN GROUP (ORDER BY SEVERITY),
        ' security ',
        CASE WHEN COUNT(DISTINCT SEVERITY) > 1 THEN 'alerts' ELSE 'alert' END,
        ' in {{ in_sf_env }} {{ in_sf_acc_name }} Snowflake.</p>',
        LISTAGG(
          CONCAT(
            '<p>',
            '<b>Severity:</b> ', SEVERITY, '<br>',
            '<b>Finding at:</b> ', START_TIMESTAMP, '<br>',
            '<b>Violation description:</b> ', SCANNER_NAME, '<br>',
            '<b>No. of Entities at risk:</b> ', TOTAL_AT_RISK_COUNT, '<br>',
            '<b>Suggested action:</b> ', SUGGESTED_ACTION,
            '</p><br>'
          ), '') WITHIN GROUP (ORDER BY SEVERITY, TOTAL_AT_RISK_COUNT DESC, SCANNER_NAME ASC)
      )
      FROM TABLE(RESULT_SCAN(SNOWFLAKE.ALERT.GET_CONDITION_QUERY_UUID()))
    )
  ),
  SNOWFLAKE.NOTIFICATION.EMAIL_INTEGRATION_CONFIG(
    '{{ in_sf_env }}_slack_alert_integration',
    '{{ in_sf_env }} {{ in_sf_acc_name }} - Daily findings alerts',
    ARRAY_CONSTRUCT({{ params_dict['alert_slack_email'] }})
  )
);

-- Alter alert to start it
ALTER ALERT {{ in_sf_env }}_LOGGING.public.security_alerts_from_trust_center RESUME;