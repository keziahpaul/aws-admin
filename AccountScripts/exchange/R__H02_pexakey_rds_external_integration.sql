USE ROLE SYSADMIN;

--1. Create network rule for Digital account VPC connectivity
CREATE NETWORK RULE IF NOT EXISTS {{in_sf_env}}_EXCHANGE_RAW.PEXAKEY.INGRESS_PEXAKEY_RDS_NR
MODE = EGRESS
TYPE = PRIVATE_HOST_PORT
VALUE_LIST = ('{{in_pexakey_rds_nlp_name}}:5432');


--2. Create Secret for Digital RDS credentials ( user and password)
CREATE SECRET IF NOT EXISTS {{in_sf_env}}_EXCHANGE_RAW.PEXAKEY.PEXAKEY_RDS_DIGITAL_CREDENTIAL
TYPE = PASSWORD
USERNAME = '{{in_pexakey_rds_username}}'
PASSWORD = '{{in_pexakey_rds_password}}';

--3. ALTER Secret for Digital RDS credentials ( user and password), if the user or password changes
ALTER SECRET {{in_sf_env}}_EXCHANGE_RAW.PEXAKEY.PEXAKEY_RDS_DIGITAL_CREDENTIAL
SET
    USERNAME = '{{in_pexakey_rds_username}}'
    PASSWORD = '{{in_pexakey_rds_password}}';

--4. Create Secret for storing the Digital RDS credentials End-point
CREATE SECRET IF NOT EXISTS {{in_sf_env}}_EXCHANGE_RAW.PEXAKEY.PEXAKEY_RDS_DIGITAL_HOST
  TYPE = GENERIC_STRING
  SECRET_STRING = '{{in_pexakey_rds_nlp_name}}'
 ;

USE ROLE ACCOUNTADMIN;

CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS {{in_sf_env}}_PEXAKEY_RDS_DIGITAL_EXTERNAL_ACCESS_INTEGRATION
ALLOWED_NETWORK_RULES = ({{in_sf_env}}_EXCHANGE_RAW.PEXAKEY.INGRESS_PEXAKEY_RDS_NR)
ALLOWED_AUTHENTICATION_SECRETS = ({{in_sf_env}}_EXCHANGE_RAW.PEXAKEY.PEXAKEY_RDS_DIGITAL_CREDENTIAL,{{in_sf_env}}_EXCHANGE_RAW.PEXAKEY.PEXAKEY_RDS_DIGITAL_HOST)
ENABLED = TRUE;

GRANT USAGE ON INTEGRATION {{in_sf_env}}_PEXAKEY_RDS_DIGITAL_EXTERNAL_ACCESS_INTEGRATION TO ROLE sysadmin;

