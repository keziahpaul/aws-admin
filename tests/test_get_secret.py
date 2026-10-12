import pytest
from unittest.mock import patch, MagicMock
import json
import sys
from io import StringIO
from botocore.exceptions import ClientError
from utils.get_secret import get_secret


class TestGetSecret:

    @patch('utils.get_secret.boto3.session.Session')
    def test_get_secret_flag_0(self, mock_session):
        """Test default behavior - prints secret value directly"""
        mock_client = MagicMock()
        mock_session.return_value.client.return_value = mock_client
        mock_client.get_secret_value.return_value = {
            'SecretString': json.dumps({'db_password': 'secret123'})
        }

        captured_output = StringIO()
        sys.stdout = captured_output

        get_secret('test-secret', 'db_password', '0')

        sys.stdout = sys.__stdout__

        assert captured_output.getvalue().strip() == 'secret123'
        mock_client.get_secret_value.assert_called_once_with(SecretId='test-secret')

    @patch('utils.get_secret.boto3.session.Session')
    def test_get_secret_flag_1(self, mock_session):
        """Test flag='1' - prints in shell export format KEY="value"""
        mock_client = MagicMock()
        mock_session.return_value.client.return_value = mock_client
        mock_client.get_secret_value.return_value = {
            'SecretString': json.dumps({'api_key': 'abc123'})
        }

        captured_output = StringIO()
        sys.stdout = captured_output

        get_secret('test-secret', 'api_key', '1', 'my_api_key')

        sys.stdout = sys.__stdout__

        # checkov:skip=CKV_SECRET_80: This is a dummy secret
        assert captured_output.getvalue().strip() == 'MY_API_KEY="abc123"'
        mock_client.get_secret_value.assert_called_once_with(SecretId='test-secret')

    @patch('utils.get_secret.boto3.session.Session')
    def test_get_secret_client_error(self, mock_session):
        """Test error handling - AWS exceptions are propagated"""
        mock_client = MagicMock()
        mock_session.return_value.client.return_value = mock_client
        mock_client.get_secret_value.side_effect = ClientError(
            {'Error': {'Code': 'ResourceNotFoundException'}}, 'GetSecretValue'
        )

        with pytest.raises(ClientError):
            get_secret('non-existent-secret', 'key', '0')

    @patch('utils.get_secret.boto3.session.Session')
    def test_get_secret_json_parsing(self, mock_session):
        """Test JSON parsing - extracts specific key from complex secret"""
        mock_client = MagicMock()
        mock_session.return_value.client.return_value = mock_client
        mock_client.get_secret_value.return_value = {
            'SecretString': json.dumps({
                'username': 'dummy_user',
                'password': 'dummy_pw'
            })
        }

        captured_output = StringIO()
        sys.stdout = captured_output

        get_secret('test-secret', 'username', '0')

        sys.stdout = sys.__stdout__

        assert captured_output.getvalue().strip() == 'dummy_user'

    @patch('utils.get_secret.boto3.session.Session')
    def test_get_secret_missing_key(self, mock_session):
        """Test error when requested key doesn't exist in secret"""
        mock_client = MagicMock()
        mock_session.return_value.client.return_value = mock_client
        mock_client.get_secret_value.return_value = {
            'SecretString': json.dumps({'username': 'dummy_user'})
        }

        with pytest.raises(KeyError):
            get_secret('test-secret', 'nonexistent_key', '0')
