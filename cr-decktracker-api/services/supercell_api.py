"""
Supercell API service layer.
Handles all communication with the Clash Royale API including caching.
"""
import asyncio
import hashlib
import json
from typing import Optional
import httpx
from fastapi import HTTPException
from config import SUPERCELL_API_BASE_URL, SUPERCELL_API_TOKEN, API_CACHE_TTL


class SupercellAPIService:
    """Service for interacting with the Supercell Clash Royale API."""

    def __init__(self, redis_client):
        """
        Initialize the API service.

        Args:
            redis_client: Redis client for caching API responses
        """
        self.redis_client = redis_client
        self.base_url = SUPERCELL_API_BASE_URL
        self.headers = {"Authorization": f"Bearer {SUPERCELL_API_TOKEN}"}

    async def get(self, path: str, params=None) -> dict:
        """
        Make a GET request to the Supercell API with Redis caching.

        Implements:
        - Redis caching (5 minutes TTL)
        - Automatic retry on rate limit (429)
        - Detailed error handling with helpful messages

        Args:
            path: API endpoint path (e.g., "/clans/{tag}/members")
            params: Optional query parameters

        Returns:
            JSON response from API

        Raises:
            HTTPException: On API errors with appropriate status codes
        """
        # Create cache key from path and params
        cache_key = f"api:{path}:{hashlib.md5(str(params).encode()).hexdigest()}"

        # Check Redis cache first
        cached = await self.redis_client.get(cache_key)
        if cached:
            print(f"✅ Cache HIT: {path}")
            return json.loads(cached)

        print(f"❌ Cache MISS: {path}")

        # Make API call
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{self.base_url}{path}",
                    headers=self.headers,
                    params=params,
                    timeout=10
                )

                # Handle rate limiting with retry
                if response.status_code == 429:
                    print(f"⚠️ Rate limited on {path}, retrying...")
                    await asyncio.sleep(1)
                    response = await client.get(
                        f"{self.base_url}{path}",
                        headers=self.headers,
                        params=params,
                        timeout=10
                    )

                # Handle 404 with helpful error messages
                if response.status_code == 404:
                    error_detail = response.json() if response.text else {}
                    reason = error_detail.get("reason", "notFound")
                    print(f"❌ 404 Not Found: {path} - {reason}")

                    # Provide context-specific error messages
                    if "clan" in path.lower():
                        raise HTTPException(
                            status_code=404,
                            detail="Clan not found. Please check that your clan tag is correct (e.g., #ABC123)."
                        )
                    elif "player" in path.lower():
                        raise HTTPException(
                            status_code=404,
                            detail="Player not found. Please check that the player tag is correct."
                        )
                    else:
                        raise HTTPException(
                            status_code=404,
                            detail="Resource not found. Please verify the information is correct."
                        )

                # Handle forbidden (invalid token)
                if response.status_code == 403:
                    print(f"❌ 403 Forbidden: {path} - Invalid API token or access denied")
                    raise HTTPException(
                        status_code=403,
                        detail="API access denied. Please check your API token."
                    )

                # Handle other errors
                if response.is_error:
                    print(f"❌ Error {response.status_code}: {path} - {response.text}")
                    raise HTTPException(status_code=response.status_code, detail=response.text)

                data = response.json()

                # Cache successful response
                await self.redis_client.setex(cache_key, API_CACHE_TTL, json.dumps(data))

                return data

        except httpx.TimeoutException:
            print(f"❌ Timeout on {path}")
            raise HTTPException(status_code=504, detail="Request to Supercell API timed out")
        except httpx.RequestError as e:
            print(f"❌ Request error on {path}: {e}")
            raise HTTPException(status_code=503, detail=f"Failed to connect to Supercell API: {str(e)}")
