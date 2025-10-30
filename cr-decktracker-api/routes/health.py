"""
Health check and system status routes.
"""
from fastapi import APIRouter
from database import SessionLocal
from models import BattleLog

router = APIRouter()


@router.get("/health")
async def health(redis_client):
    """
    Health check endpoint.
    Returns status of Redis and database connections.
    """
    redis_status = await redis_client.ping()
    return {
        "ok": True,
        "redis": "connected" if redis_status else "disconnected",
        "database": "connected"
    }


@router.get("/stats")
async def stats(redis_client):
    """
    Get cache and database statistics.
    Shows battle logs cached and Redis hit/miss rates.
    """
    db = SessionLocal()
    try:
        battle_count = db.query(BattleLog).count()

        # Redis info
        redis_info = await redis_client.info("stats")

        return {
            "database": {
                "battle_logs_cached": battle_count
            },
            "redis": {
                "keyspace_hits": redis_info.get("keyspace_hits", 0),
                "keyspace_misses": redis_info.get("keyspace_misses", 0)
            }
        }
    finally:
        db.close()


@router.delete("/cache/clear")
async def clear_cache(redis_client):
    """
    Clear all Redis cache.
    Admin endpoint for cache management.
    """
    await redis_client.flushdb()
    return {"message": "Redis cache cleared successfully"}
