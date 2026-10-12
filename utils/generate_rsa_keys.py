from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
import secrets
import string
import boto3
import boto3.session
import sys
from botocore.exceptions import ClientError

def passphrase_generation():
    alphabet = string.ascii_letters + string.digits
    password = ''.join(secrets.choice(alphabet) for i in range(20))
    return password.encode('ASCII')

def private_key_generation(private_key,private_key_pass):
    return private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.BestAvailableEncryption(private_key_pass)
        )

def public_key_generation(private_key):
    return private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
        )

def upload_secrets_to_aws(client,secret_name, description, secret_string):
    response = client.create_secret(
        Name =secret_name,
        Description = description,
        SecretString = secret_string)

def update_secrets_in_aws(client,secret_name, description, secret_string):
    response = client.update_secret(
        SecretId =secret_name,
        Description = description,
        SecretString = secret_string)

# you can use this function for testing
def upload_secrets_to_file(client,secret_name, description, secret_string):
    key_file = open(secret_name, "w")
    key_file.write(secret_string)
    key_file.close()

def generate_key_pairs(env_val,project_name,keypair_flag, service_users_list):

    if env_val in ('prd'):
        env_name = 'prod'
    elif env_val in ('pst'):
        env_name = 'pre-prod'
    else:
        env_name = 'nonprod'

    session = boto3.Session()
    client = session.client(service_name='secretsmanager')


    for service_user in service_users_list:
        private_key = rsa.generate_private_key(
                    public_exponent=65537,
                    key_size=2048)
        private_key_pass = passphrase_generation()
        encrypted_pem_private_key=private_key_generation(private_key,private_key_pass)
        pem_public_key=public_key_generation(private_key)


        secrets_list = {
                        'private-key': encrypted_pem_private_key.decode(),
                        'passphrase': private_key_pass.decode(),
                        'public-key': pem_public_key.decode().replace('-----BEGIN PUBLIC KEY-----','').replace('-----END PUBLIC KEY-----','')
                    }


        for k,v in secrets_list.items():
            if service_user in ('github-admin','github') and k=='private-key':
                v.replace('-----BEGIN ENCRYPTED PRIVATE KEY-----','').replace('-----END ENCRYPTED PRIVATE KEY-----','')

            if service_user == 'github-admin':
                secret_name='onedata_'+env_name+'_'+project_name+'_snowflake-'+service_user+'-user-'+k
            else:
                secret_name='onedata_'+env_name+'_'+env_val+'_'+project_name+'_snowflake-'+service_user+'-user-'+k

            secret_exists = client.list_secrets(Filters=[{
                                                            'Key':'name',
                                                            'Values': [secret_name]
                                                        }]
                                                )
            if not secret_exists.get('SecretList'):
                print('uploading '+secret_name+' to aws secrets manager')
                upload_secrets_to_aws(client=client,secret_name=secret_name,
                                description='This secret stores snowflake '+ k + ' for '+project_name+' '+ env_val+'_'+service_user+'_integration_user ',
                                secret_string=v)
                print('uploaded '+secret_name+' to aws secrets manager')
            elif secret_exists.get('SecretList') and keypair_flag=='update':
                print('updating '+secret_name+' to aws secrets manager')
                update_secrets_in_aws(client=client,secret_name=secret_name,
                                description='This secret stores snowflake '+ k + ' for '+project_name+' '+ env_val+'_'+service_user+'_integration_user ',
                                secret_string=v)
                print('updated '+secret_name+' to aws secrets manager')
            else:
                print('secret '+secret_name+' already exists in aws secrets manager')
            #onedata/nonprod/dev/sandbox/snowflake-dbt-user-private-key


if __name__ == "__main__":
    env_val = sys.argv[1]
    project_name = sys.argv[2]
    keypair_flag=sys.argv[3]
    service_users = sys.argv[4]
    service_users_list =service_users.replace(' ','').split(",")

    if keypair_flag in ('yes','update') and set(service_users_list).issubset(['dbt','fivetran','github-admin','github','alation','tableau','sagemaker', 'ssa_dbt','glue','bigid']):

        generate_key_pairs(env_val,project_name,keypair_flag,service_users_list)
    elif keypair_flag == 'no':
        print('You chose not to generate key pairs')
    else:
        print('Please check the service user name. Accepted Values are dbt,fievtran,github-admin,github,alation,tableau,sagemaker,bigid.')
