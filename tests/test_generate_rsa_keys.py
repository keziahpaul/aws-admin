import pytest
from unittest.mock import patch, MagicMock, call
from cryptography.hazmat.primitives.asymmetric import rsa
from utils.generate_rsa_keys import (
    passphrase_generation,
    private_key_generation,
    public_key_generation,
    generate_key_pairs
)


class TestGenerateRsaKeys:

    def test_passphrase_generation(self):
        """Test passphrase generation creates secure random password
        
        Purpose: Validates that passphrases are cryptographically secure
        for protecting RSA private keys in AWS Secrets Manager.
        """
        passphrase1 = passphrase_generation()
        passphrase2 = passphrase_generation()

        # Passphrase must be bytes for cryptography library compatibility
        assert isinstance(passphrase1, bytes)
        # Fixed length ensures consistent security level across all keys
        assert len(passphrase1) == 20
        # ASCII encoding ensures compatibility with various systems
        assert passphrase1.decode('ASCII')
        # Verify randomness - critical for security, no two passphrases should match
        assert passphrase1 != passphrase2

    def test_private_key_generation(self):
        """Test private key generation creates encrypted PEM format
        
        Purpose: Ensures private keys are properly encrypted before storage.
        Snowflake requires PKCS8 encrypted format for authentication.
        """
        # Standard RSA parameters used by Snowflake
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        passphrase = b'test_passphrase'

        encrypted_key = private_key_generation(private_key, passphrase)

        # Must be bytes for AWS Secrets Manager storage
        assert isinstance(encrypted_key, bytes)
        # Verify PKCS8 encrypted format - required by Snowflake
        assert b'-----BEGIN ENCRYPTED PRIVATE KEY-----' in encrypted_key
        assert b'-----END ENCRYPTED PRIVATE KEY-----' in encrypted_key

    def test_public_key_generation(self):
        """Test public key generation creates Snowflake-compatible format
        
        Purpose: Validates public key extraction for Snowflake user configuration.
        The public key is uploaded to Snowflake to enable key-pair authentication.
        """
        # Generate standard RSA key pair
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

        public_key = public_key_generation(private_key)

        # Must be bytes for consistent handling
        assert isinstance(public_key, bytes)
        # Standard PEM format expected by Snowflake
        assert b'-----BEGIN PUBLIC KEY-----' in public_key
        assert b'-----END PUBLIC KEY-----' in public_key
        # RSA 2048 keys have substantial size - validates key generation worked
        assert len(public_key) > 200

    @patch('utils.generate_rsa_keys.boto3.Session')
    def test_generate_key_pairs_new_secrets(self, mock_session):
        """Test key pair generation creates new secrets when they don't exist
        
        Purpose: Validates the primary workflow for initial key generation.
        This is the most common scenario when setting up new service users.
        """
        # Mock AWS Secrets Manager client
        mock_client = MagicMock()
        mock_session.return_value.client.return_value = mock_client
        # Simulate no existing secrets found
        mock_client.list_secrets.return_value = {'SecretList': []}

        with patch('utils.generate_rsa_keys.rsa.generate_private_key') as mock_rsa, \
             patch('utils.generate_rsa_keys.passphrase_generation') as mock_passphrase:

            # Mock key generation with proper values
            mock_private_key = MagicMock()
            mock_rsa.return_value = mock_private_key
            mock_passphrase.return_value = b'test_passphrase_123'

            # Mock key serialization
            mock_private_key.private_bytes.return_value = b'-----BEGIN ENCRYPTED PRIVATE KEY-----\ntest_private\n-----END ENCRYPTED PRIVATE KEY-----'
            mock_public_key = MagicMock()
            mock_private_key.public_key.return_value = mock_public_key
            mock_public_key.public_bytes.return_value = b'-----BEGIN PUBLIC KEY-----\ntest_public\n-----END PUBLIC KEY-----'

            # Execute key generation for DBT service user in dev environment
            generate_key_pairs('dev', 'sandbox', 'yes', ['dbt'])

            # Each service user requires 3 secrets: private-key, passphrase, public-key
            assert mock_client.create_secret.call_count == 3
            # Verify AWS secret naming follows expected pattern for downstream consumption
            call_args = [call[1]['Name'] for call in mock_client.create_secret.call_args_list]
            assert any('private-key' in name for name in call_args)  # For Snowflake authentication
            assert any('passphrase' in name for name in call_args)   # For private key decryption
            assert any('public-key' in name for name in call_args)   # For Snowflake user setup

    @patch('utils.generate_rsa_keys.boto3.Session')
    def test_generate_key_pairs_existing_secrets(self, mock_session):
        """Test key pair generation skips when secrets already exist
        
        Purpose: Prevents accidental overwriting of active keys.
        Critical for production safety - avoids breaking existing integrations.
        """
        # Mock AWS client with existing secrets
        mock_client = MagicMock()
        mock_session.return_value.client.return_value = mock_client
        # Simulate existing secrets found in AWS
        mock_client.list_secrets.return_value = {'SecretList': [{'Name': 'existing_secret'}]}

        with patch('utils.generate_rsa_keys.rsa.generate_private_key') as mock_rsa, \
             patch('utils.generate_rsa_keys.passphrase_generation') as mock_passphrase:

            # Mock key generation with proper values
            mock_private_key = MagicMock()
            mock_rsa.return_value = mock_private_key
            mock_passphrase.return_value = b'test_passphrase_123'

            # Mock key serialization
            mock_private_key.private_bytes.return_value = b'-----BEGIN ENCRYPTED PRIVATE KEY-----\ntest_private\n-----END ENCRYPTED PRIVATE KEY-----'
            mock_public_key = MagicMock()
            mock_private_key.public_key.return_value = mock_public_key
            mock_public_key.public_bytes.return_value = b'-----BEGIN PUBLIC KEY-----\ntest_public\n-----END PUBLIC KEY-----'

            # Attempt key generation with existing secrets present
            generate_key_pairs('dev', 'sandbox', 'yes', ['dbt'])

            # Safety check: no new secrets should be created to protect existing keys
            mock_client.create_secret.assert_not_called()

    @patch('utils.generate_rsa_keys.boto3.Session')
    def test_generate_key_pairs_update_existing(self, mock_session):
        """Test key pair generation updates existing secrets when flag is 'update'
        
        Purpose: Enables key rotation for security compliance.
        Used when keys need to be refreshed due to security policies or compromise.
        """
        # Mock AWS client with existing secrets
        mock_client = MagicMock()
        mock_session.return_value.client.return_value = mock_client
        # Simulate existing secrets that need rotation
        mock_client.list_secrets.return_value = {'SecretList': [{'Name': 'existing_secret'}]}

        with patch('utils.generate_rsa_keys.rsa.generate_private_key') as mock_rsa, \
             patch('utils.generate_rsa_keys.passphrase_generation') as mock_passphrase:

            # Mock key generation with proper values
            mock_private_key = MagicMock()
            mock_rsa.return_value = mock_private_key
            mock_passphrase.return_value = b'test_passphrase_123'

            # Mock key serialization
            mock_private_key.private_bytes.return_value = b'-----BEGIN ENCRYPTED PRIVATE KEY-----\ntest_private\n-----END ENCRYPTED PRIVATE KEY-----'
            mock_public_key = MagicMock()
            mock_private_key.public_key.return_value = mock_public_key
            mock_public_key.public_bytes.return_value = b'-----BEGIN PUBLIC KEY-----\ntest_public\n-----END PUBLIC KEY-----'

            # Execute key rotation with explicit 'update' flag
            generate_key_pairs('dev', 'sandbox', 'update', ['dbt'])

            # Verify key rotation completed - all 3 components updated atomically
            assert mock_client.update_secret.call_count == 3
            # Ensure all secret types were rotated to maintain authentication integrity
            call_args = [call[1]['SecretId'] for call in mock_client.update_secret.call_args_list]
            assert any('private-key' in name for name in call_args)  # New private key
            assert any('passphrase' in name for name in call_args)   # New passphrase
            assert any('public-key' in name for name in call_args)   # Corresponding public key

    @patch('utils.generate_rsa_keys.boto3.Session')
    def test_multiple_service_users(self, mock_session):
        """Test key generation for multiple service users
        
        Purpose: Validates batch processing for multiple integrations.
        Common scenario when setting up complete environment (DBT + Fivetran + etc).
        """
        mock_client = MagicMock()
        mock_session.return_value.client.return_value = mock_client
        # No existing secrets for clean batch generation
        mock_client.list_secrets.return_value = {'SecretList': []}

        with patch('utils.generate_rsa_keys.rsa.generate_private_key') as mock_rsa, \
             patch('utils.generate_rsa_keys.passphrase_generation') as mock_passphrase:

            mock_private_key = MagicMock()
            mock_rsa.return_value = mock_private_key
            mock_passphrase.return_value = b'test_passphrase_123'
            mock_private_key.private_bytes.return_value = b'test_private_key'
            mock_public_key = MagicMock()
            mock_private_key.public_key.return_value = mock_public_key
            mock_public_key.public_bytes.return_value = b'-----BEGIN PUBLIC KEY-----\ntest_public\n-----END PUBLIC KEY-----'

            # Generate keys for multiple service users in single operation
            generate_key_pairs('dev', 'sandbox', 'yes', ['dbt', 'fivetran'])

            # Each user needs 3 secrets, so 2 users = 6 total secrets
            # This validates the function properly iterates through all users
            assert mock_client.create_secret.call_count == 6

    @patch('utils.generate_rsa_keys.boto3.Session')
    def test_invalid_service_user_handling(self, mock_session):
        """Test handling of invalid service user names
        
        Purpose: Validates input validation prevents unauthorized key generation.
        Security measure to ensure only approved service users get keys.
        """
        mock_client = MagicMock()
        mock_session.return_value.client.return_value = mock_client
        
        # Function should validate service user names against allowed list
        # Invalid users should not trigger any AWS operations
        with patch('utils.generate_rsa_keys.rsa.generate_private_key') as mock_rsa, \
             patch('utils.generate_rsa_keys.passphrase_generation') as mock_passphrase:
            
            # Mock key generation with proper values even though they won't be used
            mock_private_key = MagicMock()
            mock_rsa.return_value = mock_private_key
            mock_passphrase.return_value = b'test_passphrase_123'
            mock_private_key.private_bytes.return_value = b'test_private_key'
            mock_public_key = MagicMock()
            mock_private_key.public_key.return_value = mock_public_key
            mock_public_key.public_bytes.return_value = b'-----BEGIN PUBLIC KEY-----\ntest_public\n-----END PUBLIC KEY-----'
            
            # Attempt to generate keys for non-approved service user
            generate_key_pairs('dev', 'sandbox', 'yes', ['invalid_user'])
            
            # Security validation: no secrets created for unauthorized users
            # Prevents accidental key generation for non-existent integrations
            mock_client.create_secret.assert_not_called()