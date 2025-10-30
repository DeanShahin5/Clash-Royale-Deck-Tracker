"""
FastAPI dependencies.
Reusable dependencies for authentication, database, and Redis.
"""
from fastapi import Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from utils.auth import decode_jwt_token
from database import get_db

# Security scheme for JWT bearer tokens
security = HTTPBearer()


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """
    FastAPI dependency to get current authenticated user from JWT token.

    Extracts and validates JWT token from Authorization header.

    Args:
        credentials: HTTP authorization credentials (Bearer token)

    Returns:
        Decoded token payload with user information

    Raises:
        HTTPException: 401 if token is invalid or expired
    """
    token = credentials.credentials
    return decode_jwt_token(token)


# Export database dependency for convenience
get_db_session = get_db
