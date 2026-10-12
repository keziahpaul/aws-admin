----- IMPORTANT NOTE: ALTER EXISTING NETWORK POLICY, in future if any new IPS needs to be added please add a alter stament if not exists else, update your IP in existing ALTER statement

--******** STEP1- Create security_network_admin user and assign to to other roles*********

-- create database and schema for network policy rules, grant usage of these to security_network_admin_user
use role SECURITYADMIN;


--******** STEP2- Create network Policies*****************************************************

--1. PEXA corporate IPs
---------- Below are GIT IPs
-- ,'52.64.92.223'
-- ,'52.65.220.188'
-- ,'52.65.28.184'
-- ,'13.54.198.44'
-- ,'52.63.120.234'
-- ,'52.64.12.252'

CREATE NETWORK POLICY IF NOT EXISTS enabled_PEXA_AND_GIT_IPV4_network ;

CREATE NETWORK POLICY IF NOT EXISTS enabled_alation_IPV4_network ;

CREATE NETWORK POLICY IF NOT EXISTS  enabled_dbt_IPV4_network;

CREATE NETWORK POLICY IF NOT EXISTS  enabled_fivetran_IPV4_network;

CREATE NETWORK POLICY IF NOT EXISTS  enabled_sagemaker_IPV4_network;

CREATE NETWORK POLICY IF NOT EXISTS  enabled_tableau_IPV4_network;

CREATE NETWORK POLICY IF NOT EXISTS enabled_bigid_IPV4_network;

----- ALTER EXISTING NETWORK POLICY, in future if any new IPS needs to be added please add a alter stament if not exists else, update your IP in existing ALTER statement
-- Allowed GIT network IPs
-- Outbound IPs from PEXA to SaaS apps per https://pexa.atlassian.net/wiki/x/6gDGuw
-- Allowed PEXA network IPs per https://pexa.atlassian.net/wiki/x/AQGQR
ALTER NETWORK POLICY IF EXISTS enabled_PEXA_AND_GIT_IPV4_network set ALLOWED_IP_LIST =
( '66.159.209.242'   -- Australia South - GP Gateway
, '66.159.210.93'    -- Australia South - GP Gateway
, '134.238.228.21'   -- Australia South - GP Gateway
, '134.238.229.90'   -- Australia South - GP Gateway
, '134.238.229.91'   -- Australia South - GP Gateway
, '134.238.229.92'   -- Australia South - GP Gateway
, '134.238.239.63'   -- Australia South - GP Gateway
, '134.238.239.64'   -- Australia South - GP Gateway
, '134.238.37.58'    -- Australia South - GP Gateway
, '134.238.37.228'   -- Australia South - GP Gateway
, '134.238.41.135'   -- Australia South - GP Gateway
, '134.238.41.136'   -- Australia South - GP Gateway
, '134.238.41.138'   -- Australia - Sydney
, '134.238.41.139'   -- Australia - NextDC CSQ
, '165.1.230.35'     -- Australia South - GP Gateway (added 30/03/2026)
, '165.1.230.36'     -- Australia South - GP Gateway (added 30/03/2026)
, '165.85.183.72'    -- Australia South - GP Gateway (added 30/03/2026)
, '165.85.183.81'    -- Australia South - GP Gateway (added 30/03/2026)
, '165.85.241.119'   -- Australia - Brisbane

, '66.159.197.2'     -- Philippines - GP Gateway
, '66.159.197.20'    -- Philippines - GP Gateway

, '66.159.216.15'    -- UK - West Village
, '208.127.55.52'    -- UK - GP Gateway
, '208.127.55.53'    -- UK - GP Gateway

, '134.238.238.21'   -- India West - GP Gateway
, '134.238.238.143'  -- India West - GP Gateway

, '165.85.0.51'      -- Japan Central - GP Gateway - fallback location
, '165.85.0.58'      -- Japan Central - GP Gateway - fallback location

, '140.209.216.189'  -- Netherlands Central - GP Gateway - fallback location
, '140.209.216.192'  -- Netherlands Central - GP Gateway - fallback location

, '130.41.64.44'     -- US Northwest - GP Gateway - fallback location
, '165.85.205.21'    -- US Northwest - GP Gateway - fallback location

, '13.54.198.44'     -- PROD - Non-PIDP
, '52.63.120.234'    -- PROD - Non-PIDP
, '52.64.12.252'     -- PROD - Non-PIDP

, '52.64.92.223'     -- Non PROD - Non-PIDP
, '52.65.28.184'     -- Non PROD - Non-PIDP
, '52.65.220.188'    -- Non PROD - Non-PIDP

, '34.99.7.53'       -- Unknown
, '34.99.7.58'       -- Unknown
, '49.255.194.210'   -- Unknown
, '49.255.195.11'    -- Unknown
, '49.255.195.194'   -- Unknown
, '52.62.164.150'    -- Unknown
, '52.63.166.42'     -- Unknown
, '52.63.216.238'    -- Unknown
, '52.64.3.139'      -- Unknown
, '52.65.97.106'     -- Unknown
, '52.65.160.53'     -- Unknown
, '165.1.228.250'    -- Unknown
, '208.127.167.193'  -- Unknown
, '208.127.214.241'  -- Unknown
, '208.127.214.254'  -- Unknown
, '208.127.214.37'   -- Unknown
);

-- Allowed alation network IPs
ALTER NETWORK POLICY IF  EXISTS enabled_alation_IPV4_network set ALLOWED_IP_LIST= ('10.98.0.0/16');

-- Allowed DBT network IPs
ALTER NETWORK POLICY IF  EXISTS  enabled_dbt_IPV4_network set ALLOWED_IP_LIST = ('10.10.0.0/16');

-- Allowed Fivetran network IPs
ALTER NETWORK POLICY IF  EXISTS  enabled_fivetran_IPV4_network set ALLOWED_IP_LIST =  ('10.130.0.0/18', '10.0.0.0/8');

-- Allowed Sagemaker network IPs
ALTER NETWORK POLICY IF  EXISTS enabled_sagemaker_IPV4_network set ALLOWED_IP_LIST= (
'10.177.64.0/20',
'10.177.80.0/20',
'10.177.96.0/20');

-- Allowed Tableau network IPs
ALTER NETWORK POLICY IF  EXISTS enabled_tableau_IPV4_network set ALLOWED_IP_LIST= (
'10.251.4.0/22',
'10.251.104.0/22',
'10.251.204.0/22',
'10.250.204.0/22',
'10.13.0.0/16');

-- Allowed BigID network IPs
ALTER NETWORK POLICY IF EXISTS enabled_bigid_IPV4_network
SET ALLOWED_IP_LIST = (
  '3.213.134.231/32',
  '104.18.0.0/16',
  '134.238.0.0/16',
  '10.157.0.0/16'
);


{% from 'modules/assign_security_roles.j2' import assign_security_roles-%}

-- Update the Alation, DBT, Fivetran, Git network policy to the respective users

{{assign_security_roles(in_sf_env)}}
