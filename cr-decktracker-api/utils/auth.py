"""
Authentication utilities.
Functions for password hashing, JWT token management, and verification.
"""
from datetime import datetime, timedelta
from typing import Optional
import bcrypt
import jwt
from fastapi import HTTPException
from config import JWT_SECRET, JWT_ALGORITHM, JWT_EXPIRATION_DAYS, BCRYPT_ROUNDS


def hash_password(password: str) -> str:
    """
    Hash a password using bcrypt with configurable salt rounds.

    Security: bcrypt is designed to be slow to prevent brute-force attacks.
    Default 12 rounds provides good security while maintaining reasonable performance.

    Args:
        password: Plain text password

    Returns:
        Hashed password string
    """
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt(rounds=BCRYPT_ROUNDS)).decode('utf-8')


def verify_password(password: str, hashed: str) -> bool:
    """
    Verify a password against its bcrypt hash.

    Security: Timing-safe comparison via bcrypt.checkpw prevents timing attacks.

    Args:
        password: Plain text password to verify
        hashed: Hashed password from database

    Returns:
        True if password matches, False otherwise
    """
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))


def create_jwt_token(email: str, player_tag: Optional[str] = None) -> str:
    """
    Create JWT token with configurable expiration.

    Security: Shorter expiration reduces risk if token is compromised.
    Default 7 days balances security and user convenience.

    Args:
        email: User email address
        player_tag: Optional player tag to include in token

    Returns:
        Encoded JWT token string
    """
    payload = {
        "email": email,
        "player_tag": player_tag,
        "exp": datetime.utcnow() + timedelta(days=JWT_EXPIRATION_DAYS)
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_jwt_token(token: str) -> dict:
    """
    Decode and verify JWT token.

    Args:
        token: JWT token string

    Returns:
        Decoded token payload

    Raises:
        HTTPException: 401 if token is expired or invalid
    """
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid token")
