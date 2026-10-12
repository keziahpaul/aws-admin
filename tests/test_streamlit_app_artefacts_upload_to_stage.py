import pytest
from unittest.mock import patch, MagicMock, mock_open, call
import os
import sys
from argparse import Namespace

# Mock snowflake module at import time
sys.modules['snowflake'] = MagicMock()
sys.modules['snowflake.connector'] = MagicMock()

from utils.streamlit_app_artefacts_upload_to_stage import upload_files


class TestStreamlitAppArtefactsUpload:

    def create_mock_args(self, **overrides):
        """Helper to create mock arguments with defaults"""
        defaults = {
            'snowflake_user': 'test_user',
            'snowflake_account': 'test_account',
            'snowflake_role': 'test_role',
            'private_key_file': '/path/to/key.pem',
            'passphrase': 'test_passphrase',
            'snowflake_database': 'test_db',
            'snowflake_schema': 'test_schema',
            'folder_name': 'TestApp',
            'internal_stage': 'test_stage'
        }
        defaults.update(overrides)
        return Namespace(**defaults)

    @patch('utils.streamlit_app_artefacts_upload_to_stage.snowflake.connector.connect')
    @patch('utils.streamlit_app_artefacts_upload_to_stage.os.path.isdir')
    @patch('utils.streamlit_app_artefacts_upload_to_stage.os.walk')
    @patch('builtins.open', new_callable=mock_open, read_data=b'test file content')
    def test_upload_files_successful(self, mock_file_open, mock_walk, mock_isdir, mock_connect):
        """Test successful file upload to Snowflake stage"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        
        mock_isdir.return_value = True
        mock_walk.return_value = [
            ('streamlit/testapp', [], ['app.py', 'requirements.txt'])
        ]
        
        args = self.create_mock_args(folder_name='TestApp')
        upload_files(args)
        
        mock_connect.assert_called_once()
        assert mock_cursor.execute.call_count == 2

    @patch('utils.streamlit_app_artefacts_upload_to_stage.snowflake.connector.connect')
    @patch('utils.streamlit_app_artefacts_upload_to_stage.os.path.isdir')
    def test_upload_files_folder_not_exists(self, mock_isdir, mock_connect):
        """Test handling when Streamlit app folder doesn't exist"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        
        mock_isdir.return_value = False
        
        args = self.create_mock_args(folder_name='NonExistentApp')
        
        with patch('utils.streamlit_app_artefacts_upload_to_stage.logger') as mock_logger:
            upload_files(args)
            mock_logger.error.assert_called_once()

    @patch('utils.streamlit_app_artefacts_upload_to_stage.snowflake.connector.connect')
    @patch('utils.streamlit_app_artefacts_upload_to_stage.os.path.isdir')
    @patch('utils.streamlit_app_artefacts_upload_to_stage.os.walk')
    def test_upload_files_snowflake_error(self, mock_walk, mock_isdir, mock_connect):
        """Test handling of Snowflake connection errors"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        
        mock_isdir.return_value = True
        mock_walk.return_value = [('streamlit/testapp', [], ['app.py'])]
        mock_cursor.execute.side_effect = Exception('Snowflake connection failed')
        
        args = self.create_mock_args()
        
        with patch('utils.streamlit_app_artefacts_upload_to_stage.logger') as mock_logger, \
             patch('builtins.open', mock_open(read_data=b'test content')):
            
            upload_files(args)
            mock_logger.error.assert_called_once()

    @patch('utils.streamlit_app_artefacts_upload_to_stage.snowflake.connector.connect')
    @patch('utils.streamlit_app_artefacts_upload_to_stage.os.path.isdir')
    @patch('utils.streamlit_app_artefacts_upload_to_stage.os.walk')
    def test_upload_files_empty_folder(self, mock_walk, mock_isdir, mock_connect):
        """Test handling of empty Streamlit app folder"""
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_connect.return_value = mock_conn
        mock_conn.cursor.return_value = mock_cursor
        
        mock_isdir.return_value = True
        mock_walk.return_value = [('streamlit/testapp', [], [])]  # No files
        
        args = self.create_mock_args()
        upload_files(args)
        
        mock_connect.assert_called_once()
        mock_cursor.execute.assert_not_called()

    def test_folder_name_case_handling(self):
        """Test that folder names are properly converted to lowercase"""
        with patch('utils.streamlit_app_artefacts_upload_to_stage.snowflake.connector.connect') as mock_connect, \
             patch('utils.streamlit_app_artefacts_upload_to_stage.os.path.isdir') as mock_isdir:
            
            mock_conn = MagicMock()
            mock_cursor = MagicMock()
            mock_connect.return_value = mock_conn
            mock_conn.cursor.return_value = mock_cursor
            mock_isdir.return_value = False
            
            args = self.create_mock_args(folder_name='MyApp')
            upload_files(args)
            
            mock_isdir.assert_called_with('streamlit/myapp')