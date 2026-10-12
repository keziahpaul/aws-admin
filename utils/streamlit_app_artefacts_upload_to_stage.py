import os
import argparse
import snowflake.connector
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def upload_files(args):
    logger.info('Connecting to Snowflake...')
    conn = snowflake.connector.connect(
        user=args.snowflake_user,
        account=args.snowflake_account,
        role=args.snowflake_role,
        private_key_file=args.private_key_file,
        private_key_file_pwd=args.passphrase,
        database=args.snowflake_database,
        schema=args.snowflake_schema

    )

    cs = conn.cursor()
    try:
        logger.info(f'Current working directory: {os.getcwd()}')
        streamlit_app_folder= 'streamlit/'+ args.folder_name.lower()
        
        logger.info(f'App folder path is {streamlit_app_folder}')

        if os.path.isdir(streamlit_app_folder):
            logger.info('Uploading files to Snowflake...')
            for root, dirs, files in os.walk(streamlit_app_folder):
                for file in files:
                    file_path = os.path.join(root, file)
                    with open(file_path, 'rb') as f:
                        file_contents = f.read()
                        cs.execute(f"PUT file://{file_path} @{args.internal_stage}/{args.folder_name} OVERWRITE = TRUE AUTO_COMPRESS = FALSE")
                        logger.info(f'Uploaded file: {file_path}')
        else:
            logger.error(f"The folder path '{streamlit_app_folder}' does not exist.")
    except Exception as e:
        logger.error(f'An error occurred: {e}')    
        
    finally:
        cs.close()
        logger.info('Closing Snowflake connection...')
        conn.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Upload files to Snowflake')
    parser.add_argument('--snowflake_user', required=True, help='Snowflake user')
    parser.add_argument('--snowflake_account', required=True, help='Snowflake account')
    parser.add_argument('--snowflake_role', required=True, help='Snowflake role')
    parser.add_argument('--snowflake_private_key', required=True, help='Snowflake private key')
    parser.add_argument('--passphrase', required=True, help='Snowflake private key passphrase')
    parser.add_argument('--folder_name', required=True, help='Folder name containing files to upload')
    parser.add_argument('--private_key_file', required=True, help='Snowflake private key file')
    parser.add_argument('--snowflake_database', required=True, help='snowflake database')
    parser.add_argument('--snowflake_schema', required=True, help='snowflake schema')
    parser.add_argument('--internal_stage', required=True, help='internal stage')

    args = parser.parse_args()
    upload_files(args)
