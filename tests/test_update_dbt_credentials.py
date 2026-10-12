import pytest
from unittest.mock import patch, MagicMock, call
import json
from utils.update_dbt_credentials import (
    get_project_id,
    get_credential_ids_list,
    fetch_secrets_from_aws,
    update_credentials,
    update_process
)


class TestUpdateDbtCredentials:

    @patch('utils.update_dbt_credentials.requests.get')
    def test_get_project_id(self, mock_get):
        """Test project ID retrieval from DBT Cloud API"""
        mock_response = MagicMock()
        mock_response.json.return_value = {
            'data': [
                {'id': 123, 'name': 'onedata-au-pexa-group'},
                {'id': 456, 'name': 'onedata-au-landinsights'}
            ]
        }
        mock_get.return_value = mock_response
        
        import utils.update_dbt_credentials as module
        module.cloud_api_base_url = 'https://test.dbt.com/api/'
        module.headers = {'Authorization': 'Token test'}
        
        project_id = get_project_id('onedata-au-pexa-group')
        
        assert project_id == '123'
        mock_get.assert_called_once()

    @patch('utils.update_dbt_credentials.requests.get')
    def test_get_credential_ids_list(self, mock_get):
        """Test credential ID extraction for specific environment and user type"""
        mock_response = MagicMock()
        mock_response.json.return_value = {
            'data': [
                {'id': 111, 'user': 'dev_dbt_integration_user'},
                {'id': 222, 'user': 'prod_dbt_integration_user'},
                {'id': 333, 'user': 'dev_fivetran_integration_user'}
            ]
        }
        mock_get.return_value = mock_response
        
        import utils.update_dbt_credentials as module
        module.cloud_api_base_url = 'https://test.dbt.com/api/'
        module.headers = {'Authorization': 'Token test'}
        
        credential_ids = get_credential_ids_list('123', 'dev', 'dbt')
        
        assert credential_ids == ['111']

    @patch('utils.update_dbt_credentials.boto3.Session')
    def test_fetch_secrets_from_aws(self, mock_session):
        """Test AWS Secrets Manager secret retrieval"""
        mock_client = MagicMock()
        mock_session.return_value.client.return_value = mock_client
        mock_client.get_secret_value.return_value = {
            'SecretString': 'test_private_key_content'
        }
        
        secret_value = fetch_secrets_from_aws('test-secret-name')
        
        assert secret_value == 'test_private_key_content'

    @patch('utils.update_dbt_credentials.requests.patch')
    def test_update_credentials(self, mock_patch):
        """Test DBT Cloud credential update via API"""
        mock_response = MagicMock()
        mock_response.json.return_value = {'status': {'code': 200}}
        mock_patch.return_value = mock_response
        
        import utils.update_dbt_credentials as module
        module.cloud_api_base_url = 'https://test.dbt.com/api/'
        module.headers = {'Authorization': 'Token test'}
        
        response = update_credentials('123', '456', 'new_private_key', 'new_passphrase')
        
        assert response == mock_response

    @patch('utils.update_dbt_credentials.update_credentials')
    @patch('utils.update_dbt_credentials.fetch_secrets_from_aws')
    @patch('utils.update_dbt_credentials.get_credential_ids_list')
    @patch('utils.update_dbt_credentials.get_project_id')
    def test_update_process_successful(self, mock_get_project_id, mock_get_creds, mock_fetch_secrets, mock_update_creds):
        """Test complete credential update process for standard DBT project"""
        mock_get_project_id.return_value = '123'
        mock_get_creds.return_value = ['456', '789']
        mock_fetch_secrets.side_effect = ['new_private_key', 'new_passphrase']
        
        mock_response = MagicMock()
        mock_response.json.return_value = {'status': {'code': 200}}
        mock_update_creds.return_value = mock_response
        
        import utils.update_dbt_credentials as module
        module.mappings = {'onedata-au-pexa-group': 'group'}
        
        update_process('onedata-au-pexa-group', 'dev')
        
        mock_get_project_id.assert_called_once_with('onedata-au-pexa-group')
        mock_get_creds.assert_called_once_with('123', 'dev', 'dbt')
        assert mock_fetch_secrets.call_count == 2
        assert mock_update_creds.call_count == 2

    @patch('utils.update_dbt_credentials.update_credentials')
    @patch('utils.update_dbt_credentials.fetch_secrets_from_aws')
    @patch('utils.update_dbt_credentials.get_credential_ids_list')
    @patch('utils.update_dbt_credentials.get_project_id')
    def test_update_process_ssa_project(self, mock_get_project_id, mock_get_creds, mock_fetch_secrets, mock_update_creds):
        """Test credential update for self-service analytics project"""
        mock_get_project_id.return_value = '123'
        mock_get_creds.return_value = ['456']
        mock_fetch_secrets.side_effect = ['ssa_private_key', 'ssa_passphrase']
        
        mock_response = MagicMock()
        mock_response.json.return_value = {'status': {'code': 200}}
        mock_update_creds.return_value = mock_response
        
        import utils.update_dbt_credentials as module
        module.mappings = {'onedata-au-pexa-group-selfservice-analytics': 'group'}
        
        update_process('onedata-au-pexa-group-selfservice-analytics', 'dev')
        
        mock_get_creds.assert_called_once_with('123', 'dev', 'ssa_dbt')

    @patch('utils.update_dbt_credentials.get_credential_ids_list')
    @patch('utils.update_dbt_credentials.get_project_id')
    def test_update_process_no_credentials(self, mock_get_project_id, mock_get_creds):
        """Test handling when no credentials found for project/environment"""
        mock_get_project_id.return_value = '123'
        mock_get_creds.return_value = []
        
        import utils.update_dbt_credentials as module
        module.mappings = {'onedata-au-pexa-group': 'group'}
        
        update_process('onedata-au-pexa-group', 'nonexistent_env')
        
        mock_get_creds.assert_called_once_with('123', 'nonexistent_env', 'dbt')