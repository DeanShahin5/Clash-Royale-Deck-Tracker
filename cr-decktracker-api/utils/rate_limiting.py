"""
Rate limiting utilities using Redis.
Protects API endpoints from abuse and brute-force attacks.
"""
from fastapi import HTTPException, Request
from config import (
    GENERAL_RATE_LIMIT,
    GENERAL_RATE_WINDOW,
    AUTH_RATE_LIMIT,
    AUTH_RATE_WINDOW,
)


async def check_rate_limit(redis_client, identifier: str) -> bool:
    """
    Check if request is within general rate limit.

    Rate: 100 requests per hour per identifier (typically IP address)

    Args:
        redis_client: Redis client instance
        identifier: Unique identifier (usually IP address)

    Returns:
        True if within limit, False if exceeded
    """
    key = f"ratelimit:{identifier}"
    count = await redis_client.get(key)

    if count is None:
        await redis_client.setex(key, GENERAL_RATE_WINDOW, 1)
        return True
    elif int(count) < GENERAL_RATE_LIMIT:
        await redis_client.incr(key)
        return True
    else:
        return False


async def check_auth_rate_limit(redis_client, identifier: str) -> bool:
    """
    Strict rate limit for authentication endpoints to prevent brute-force attacks.

    Rate: 5 attempts per minute per IP address

    Security: Prevents credential stuffing and brute-force password attacks.

    Args:
        redis_client: Redis client instance
        identifier: Unique identifier (usually IP address)

    Returns:
        True if within limit, False if exceeded
    """
    key = f"auth_ratelimit:{identifier}"
    count = await redis_client.get(key)

    if count is None:
        await redis_client.setex(key, AUTH_RATE_WINDOW, 1)
        return True
    elif int(count) < AUTH_RATE_LIMIT:
        await redis_client.incr(key)
        return True
    else:
        return False


async def require_auth_rate_limit(request: Request, redis_client):
    """
    FastAPI dependency to enforce auth rate limiting.

    Uses client IP address as identifier (handles proxy headers).

    Args:
        request: FastAPI request object
        redis_client: Redis client instance

    Raises:
        HTTPException: 429 if rate limit exceeded

    Returns:
        True if within limit
    """
    # Get client IP (handle proxy headers)
    client_ip = request.client.host
    if forwarded_for := request.headers.get("X-Forwarded-For"):
        client_ip = forwarded_for.split(",")[0].strip()

    if not await check_auth_rate_limit(redis_client, client_ip):
        raise HTTPException(
            status_code=429,
            detail="Too many authentication attempts. Please try again in 1 minute."
        )
    return True
