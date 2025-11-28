"""
RSA-PSS signing for Kalshi API authentication.

This module handles the cryptographic signing required for Kalshi API requests.
"""

import base64
import time
from typing import Optional
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.backends import default_backend


def sign_kalshi_request(
    method: str,
    path: str,
    api_key: str,
    private_key_pem: str,
    body: Optional[str] = None,
    path_prefix: str = "/trade-api/v2/",
) -> dict:
    """
    Generate Kalshi API authentication headers using RSA-PSS signing.
    
    Args:
        method: HTTP method (GET, POST, etc.)
        path: API path (e.g., "portfolio/balance" - without leading slash or prefix)
        api_key: Kalshi API key ID
        private_key_pem: RSA private key in PEM format (string)
        body: Optional request body (for POST/PUT requests)
        path_prefix: Path prefix for signing (default: "/trade-api/v2/")
    
    Returns:
        Dictionary with KALSHI-ACCESS-KEY, KALSHI-ACCESS-TIMESTAMP, KALSHI-ACCESS-SIGNATURE
    """
    # Generate timestamp (milliseconds since epoch)
    timestamp_ms = str(int(time.time() * 1000))
    
    # Remove query string from path if present
    path_no_query = path.split('?')[0]
    
    # Build full path for signing: prefix + path
    full_path = f"{path_prefix}{path_no_query}"
    
    # Create signature payload
    # Format: timestamp + method + full_path (no body for GET requests)
    # Per Kalshi docs: timestamp + method + path (no query, no body for GET)
    method_upper = method.upper()
    signature_payload = f"{timestamp_ms}{method_upper}{full_path}"
    if body:
        signature_payload += body
    
    try:
        # Load private key from PEM string
        private_key = serialization.load_pem_private_key(
            private_key_pem.encode('utf-8'),
            password=None,
            backend=default_backend()
        )
        
        # Sign with RSA-PSS
        # Kalshi uses PSS with SHA-256
        signature = private_key.sign(
            signature_payload.encode('utf-8'),
            padding.PSS(
                mgf=padding.MGF1(hashes.SHA256()),
                salt_length=padding.PSS.MAX_LENGTH
            ),
            hashes.SHA256()
        )
        
        # Encode signature as base64
        signature_b64 = base64.b64encode(signature).decode('utf-8')
        
        return {
            "KALSHI-ACCESS-KEY": api_key,
            "KALSHI-ACCESS-TIMESTAMP": timestamp_ms,
            "KALSHI-ACCESS-SIGNATURE": signature_b64,
        }
    except Exception as e:
        raise ValueError(f"Failed to sign request: {e}")


def load_private_key_from_file(file_path: str) -> str:
    """
    Load RSA private key from a file.
    
    Args:
        file_path: Path to .key file
    
    Returns:
        Private key as PEM string
    """
    with open(file_path, 'r') as f:
        return f.read()


def load_private_key_from_string(key_string: str) -> str:
    """
    Load RSA private key from a string (handles both PEM and raw key formats).
    
    Args:
        key_string: Private key as string (may include newlines, etc.)
    
    Returns:
        Private key as PEM string
    """
    # If it already looks like PEM, return as-is
    if "BEGIN" in key_string and "PRIVATE KEY" in key_string:
        return key_string
    
    # Otherwise, assume it's already in the right format
    return key_string

