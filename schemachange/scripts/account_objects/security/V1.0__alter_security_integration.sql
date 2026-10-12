--  this script is designed to run as a one time only.

-- snyc_password must be set to false in both OKTA and in security integration
ALTER SECURITY INTEGRATION OKTA_PROVISIONING SET SYNC_PASSWORD = FALSE;

-- if user is root admin user do not update password to null
-- and only perform this alter for users that have not been deleted -> this issue came about as it kept trying to alter password
-- for a previously dropped user MLIM. No idea why because that MLIM has definitely been dropped and does not exist.
EXECUTE IMMEDIATE $$
DECLARE
    users CURSOR FOR SELECT name FROM SNOWFLAKE.ACCOUNT_USAGE.USERS WHERE has_password = TRUE AND name NOT LIKE '%ADMIN%' AND deleted_on is NULL AND COALESCE(expires_at, CURRENT_TIMESTAMP) >= CURRENT_TIMESTAMP;
BEGIN
    OPEN users;
    FOR record IN users DO
        LET user_name varchar := '"' || record.name || '"';
        ALTER USER IDENTIFIER(:user_name) SET PASSWORD = NULL;
    END FOR;
    CLOSE users;
END;
$$
;
