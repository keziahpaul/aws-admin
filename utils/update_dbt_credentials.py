import boto3
import boto3.session
import requests
import sys




def update_process(project_name,env_val):
    project_id = get_project_id(project_name)
    user_type = 'dbt'
    if project_name=='onedata-au-pexa-group-selfservice-analytics':
        user_type='ssa_dbt'
    credendial_ids_list = get_credential_ids_list(project_id,env_val,user_type)
    if len(credendial_ids_list)>0:
        snowflake_account_name = mappings[project_name]
        if env_val in ('prd'):
            env_name = 'prod'
        elif env_val in ('pst'):
            env_name = 'pre-prod'
        else:
            env_name = 'nonprod'
        secret_name = 'onedata_'+env_name+'_'+env_val+'_'+snowflake_account_name+'_snowflake-'+user_type+'-user-' 
        secret_private_key = fetch_secrets_from_aws(secret_name.lower()+'private-key')
        secret_passphrase= fetch_secrets_from_aws(secret_name.lower()+'passphrase')
        for cred_id in credendial_ids_list:
            response = update_credentials(project_id,cred_id,secret_private_key,secret_passphrase)
            if response.json().get('status')["code"]==200:
                print('DBT credential is sucessfully updated for '+project_name +' and environment '+env_val)
    else:
         print("There are no credentials available to update with this project "+project_name +" and environment "+env_val+" combination.")



def get_project_id(project_name):
    response= requests.get(f'{cloud_api_base_url}', headers=headers)
    projects_result = response.json()
    dbt_projects = projects_result.get('data')
    for project in dbt_projects:
        if project['name'] == project_name:
            project_id = project['id'] 
    return str(project_id)


def get_credential_ids_list(project_id, env_val, user_type):
    response= requests.get(f'{cloud_api_base_url}'+project_id+"/credentials", headers=headers)
    credentials_result = response.json()
    credentials = credentials_result.get('data')
    credential_id_list =[]
    for credential in credentials:
        if credential["user"].lower() == env_val+"_"+user_type+"_integration_user":
            credential_id_list.append(str(credential['id']))
    return credential_id_list



def fetch_secrets_from_aws(secret_name):
    session = boto3.Session()
    client = session.client(service_name='secretsmanager') 
    response = client.get_secret_value(
        SecretId=secret_name
    )
    return response['SecretString']

def update_credentials(project_id,credential_id,secret_private_key,secret_passphrase):
    payload= {
    "private_key": secret_private_key,
    "private_key_passphrase": secret_passphrase
    }

    response = requests.patch( f'{cloud_api_base_url}'+project_id+"/credentials/"+credential_id, json=payload,  headers=headers)
    return response





if __name__ == "__main__":
    mappings={'onedata-au-dbt-common-lib' :'sandbox',
            'onedata-au-sandbox':'sandbox',
            'onedata-au-landinsights':'landinsights',
            'onedata-au-landinsights-prod':'landinsights',
            'onedata-au-pexa-exchange': 'exchange',
            'onedata-au-pexa-exchange-prod': 'exchange',
            'onedata-au-pexa-group':'group',
            'onedata-au-pexa-group-prod':'group',
            'onedata-au-pexa-group-selfservice-analytics': 'group',
            'onedata-au-value-australia': 'value-australia',
            'onedata-au-value-australia-prod': 'value-australia'
        }
    
    env_val = sys.argv[1]
    project_name = sys.argv[2]
    api_key = sys.argv[3]

    headers = {
    "Accept": "application/json",
    "Authorization": f"Token {api_key}"
    }

    cloud_api_base_url = 'https://au.dbt.com/api/v3/accounts/70/projects/' 
    #4713/credentials/15911'

    if project_name=="all":
        for project_name in mappings:
            update_process(project_name,env_val)
    elif project_name in mappings:
        update_process(project_name,env_val)
    else:
        print(f"Unknown project_name - {project_name}")


