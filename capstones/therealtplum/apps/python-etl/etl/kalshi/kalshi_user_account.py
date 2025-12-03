"""
Kalshi user account integration.

Handles:
- Secure storage of user Kalshi API credentials
- Fetching user balance and portfolio positions
- Authenticated API requests with RSA-PSS signing
"""

import os
import json
import logging
import hashlib
import base64
from typing import Optional, Dict, Any
from cryptography.fernet import Fernet
import requests
import psycopg2
from dotenv import load_dotenv

# Load .env file if it exists
load_dotenv()

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgres://app:app@db:5432/fmhub")

# Encryption key for storing credentials
# In production, this should be from environment variable or key management service
ENCRYPTION_KEY = os.getenv("KALSHI_CREDENTIALS_ENCRYPTION_KEY")

# Kalshi API configuration
KALSHI_BASE_URL = os.getenv("KALSHI_BASE_URL", "https://api.elections.kalshi.com/trade-api/v2")

logging.basicConfig(
    level=logging.INFO,
    format="[kalshi_user_account] %(message)s",
)
log = logging.getLogger(__name__)


class KalshiCredentialsManager:
    """
    Manages secure storage and retrieval of user Kalshi credentials.
    
    Credentials are encrypted at rest using Fernet (symmetric encryption).
    """
    
    def __init__(self, encryption_key: Optional[str] = None):
        if not encryption_key:
            raise ValueError("Encryption key is required for credential storage")
        
        # Generate Fernet key from provided key
        key_bytes = encryption_key.encode() if isinstance(encryption_key, str) else encryption_key
        # Fernet requires 32-byte key, so we hash if needed
        if len(key_bytes) != 32:
            key_bytes = hashlib.sha256(key_bytes).digest()
        
        self.cipher = Fernet(base64.urlsafe_b64encode(key_bytes))
    
    def encrypt_credentials(self, api_key: str, api_secret: str) -> str:
        """Encrypt Kalshi API credentials."""
        credentials = json.dumps({
            "api_key": api_key,
            "api_secret": api_secret,
        })
        return self.cipher.encrypt(credentials.encode()).decode()
    
    def decrypt_credentials(self, encrypted: str) -> Dict[str, str]:
        """Decrypt Kalshi API credentials."""
        decrypted = self.cipher.decrypt(encrypted.encode())
        return json.loads(decrypted.decode())


def get_conn():
    return psycopg2.connect(DATABASE_URL)


def store_user_credentials(
    user_id: str,
    api_key: str,
    api_secret: str,
    encryption_key: Optional[str] = None,
) -> bool:
    """
    Store encrypted Kalshi credentials for a user.
    
    Args:
        user_id: Unique user identifier
        api_key: Kalshi API key
        api_secret: Kalshi API secret (private key)
        encryption_key: Encryption key (defaults to ENCRYPTION_KEY env var)
    
    Returns:
        True if successful
    """
    if not encryption_key:
        encryption_key = ENCRYPTION_KEY
    
    if not encryption_key:
        raise ValueError("Encryption key required for storing credentials")
    
    manager = KalshiCredentialsManager(encryption_key)
    encrypted = manager.encrypt_credentials(api_key, api_secret)
    
    conn = get_conn()
    cur = conn.cursor()
    
    try:
        # Upsert credentials
        cur.execute(
            """
            INSERT INTO kalshi_user_credentials (
                user_id,
                encrypted_credentials,
                api_key_id
            )
            VALUES (%s, %s, %s)
            ON CONFLICT (user_id)
            DO UPDATE SET
                encrypted_credentials = EXCLUDED.encrypted_credentials,
                api_key_id = EXCLUDED.api_key_id,
                updated_at = NOW()
            """,
            (user_id, encrypted, api_key),  # Using api_key as api_key_id for now
        )
        conn.commit()
        log.info(f"Stored credentials for user: {user_id}")
        return True
    except Exception as e:
        log.error(f"Error storing credentials: {e}")
        conn.rollback()
        return False
    finally:
        cur.close()
        conn.close()


def get_user_credentials(
    user_id: str,
    encryption_key: Optional[str] = None,
) -> Optional[Dict[str, str]]:
    """
    Retrieve and decrypt user Kalshi credentials.
    
    Args:
        user_id: Unique user identifier
        encryption_key: Encryption key (defaults to ENCRYPTION_KEY env var)
    
    Returns:
        Dictionary with 'api_key' and 'api_secret', or None if not found
    """
    if not encryption_key:
        encryption_key = ENCRYPTION_KEY
    
    if not encryption_key:
        raise ValueError("Encryption key required for retrieving credentials")
    
    conn = get_conn()
    cur = conn.cursor()
    
    try:
        cur.execute(
            """
            SELECT encrypted_credentials
            FROM kalshi_user_credentials
            WHERE user_id = %s
            """,
            (user_id,),
        )
        row = cur.fetchone()
        
        if not row:
            return None
        
        manager = KalshiCredentialsManager(encryption_key)
        return manager.decrypt_credentials(row[0])
    except Exception as e:
        log.error(f"Error retrieving credentials: {e}")
        return None
    finally:
        cur.close()
        conn.close()


def delete_user_credentials(user_id: str) -> bool:
    """Delete user credentials."""
    conn = get_conn()
    cur = conn.cursor()
    
    try:
        cur.execute(
            """
            DELETE FROM kalshi_user_credentials
            WHERE user_id = %s
            """,
            (user_id,),
        )
        conn.commit()
        log.info(f"Deleted credentials for user: {user_id}")
        return True
    except Exception as e:
        log.error(f"Error deleting credentials: {e}")
        conn.rollback()
        return False
    finally:
        cur.close()
        conn.close()


class KalshiAuthenticatedClient:
    """
    Client for making authenticated requests to Kalshi API.
    
    Handles RSA-PSS signing for authentication.
    """
    
    def __init__(self, api_key: str, api_secret: str):
        self.api_key = api_key
        self.api_secret = api_secret
        self.base_url = KALSHI_BASE_URL
    
    def _sign_request(self, method: str, path: str, body: Optional[str] = None) -> Dict[str, str]:
        """
        Generate authentication headers using RSA-PSS signing.
        
        Args:
            method: HTTP method (GET, POST, etc.)
            path: API path (e.g., "portfolio/balance" - without leading slash)
            body: Optional request body
        
        Returns:
            Dictionary of authentication headers
        """
        try:
            from etl.kalshi.kalshi_rsa_signing import sign_kalshi_request
            # Remove leading slash if present, as we add the prefix
            clean_path = path.lstrip('/')
            return sign_kalshi_request(
                method=method,
                path=clean_path,
                api_key=self.api_key,
                private_key_pem=self.api_secret,
                body=body,
            )
        except ImportError:
            log.warning("kalshi_rsa_signing module not available, using placeholder")
            # Fallback to placeholder if signing module not available
            import time
            timestamp = str(int(time.time() * 1000))
            return {
                "KALSHI-ACCESS-KEY": self.api_key,
                "KALSHI-ACCESS-TIMESTAMP": timestamp,
                "KALSHI-ACCESS-SIGNATURE": "placeholder",
            }
        except Exception as e:
            log.error(f"Failed to sign request: {e}")
            raise
    
    def get_balance(self) -> Optional[Dict[str, Any]]:
        """Fetch user account balance."""
        path = "portfolio/balance"  # No leading slash - will be prefixed in signing
        headers = self._sign_request("GET", path)
        
        try:
            # base_url is https://api.elections.kalshi.com/trade-api/v2, append /path
            url = f"{self.base_url}/{path}"
            resp = requests.get(
                url,
                headers=headers,
                timeout=10,
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            log.error(f"Error fetching balance: {e}")
            return None
    
    def get_positions(self) -> Optional[Dict[str, Any]]:
        """Fetch user portfolio positions."""
        path = "portfolio/positions"  # No leading slash - will be prefixed in signing
        headers = self._sign_request("GET", path)
        
        try:
            # base_url already includes /trade-api/v2/, just append path
            url = f"{self.base_url.rstrip('/')}/{path}"
            resp = requests.get(
                url,
                headers=headers,
                timeout=10,
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            log.error(f"Error fetching positions: {e}")
            return None
    
    def get_user_account(self) -> Optional[Dict[str, Any]]:
        """Fetch user account information."""
        path = "portfolio"  # No leading slash - will be prefixed in signing
        headers = self._sign_request("GET", path)
        
        try:
            # base_url already includes /trade-api/v2/, just append path
            url = f"{self.base_url.rstrip('/')}/{path}"
            resp = requests.get(
                url,
                headers=headers,
                timeout=10,
            )
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            log.error(f"Error fetching account: {e}")
            return None


def fetch_user_account_data(user_id: str) -> Optional[Dict[str, Any]]:
    """
    Fetch user's Kalshi account data (balance, positions, etc.).
    
    Args:
        user_id: Unique user identifier
    
    Returns:
        Dictionary with account data, or None if error
    """
    credentials = get_user_credentials(user_id)
    if not credentials:
        log.warning(f"No credentials found for user: {user_id}")
        return None
    
    client = KalshiAuthenticatedClient(
        credentials["api_key"],
        credentials["api_secret"],
    )
    
    balance = client.get_balance()
    positions = client.get_positions()
    account = client.get_user_account()
    
    return {
        "balance": balance,
        "positions": positions,
        "account": account,
        "fetched_at": None,  # Could add timestamp
    }

