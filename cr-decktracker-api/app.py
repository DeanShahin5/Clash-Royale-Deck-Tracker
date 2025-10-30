"""
Clash Royale Deck Tracker API - Main Application

A modular FastAPI application for tracking Clash Royale player and clan statistics.
Organized into clean, maintainable modules for routes, services, and utilities.
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
import redis.asyncio as redis

# Configuration
from config import REDIS_URL

# Database
from database import init_db

# Middleware
from middleware.security import setup_cors, add_security_headers

# Routes
from routes import health, auth, player, clan


# Global Redis client - accessible by all routes
redis_client = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan manager.
    Handles startup and shutdown for Redis and database connections.
    """
    global redis_client

    # Startup: Connect to Redis and initialize database
    redis_client = await redis.from_url(REDIS_URL, decode_responses=True)
    print("✅ Connected to Redis")

    init_db()

    yield

    # Shutdown: Close Redis connection
    await redis_client.close()
    print("❌ Disconnected from Redis")


# Create FastAPI application
app = FastAPI(
    title="Clash Royale Deck Tracker API",
    version="2.0",
    description="Modular API for tracking Clash Royale player and clan statistics",
    lifespan=lifespan
)

# Configure CORS
setup_cors(app)

# Add security headers to all responses
app.middleware("http")(add_security_headers)


# Function to inject Redis client into route handlers
def get_redis():
    """Get the global Redis client instance."""
    return redis_client


# Patch route handlers to inject redis_client
# This allows routes to receive redis_client as a parameter
for router_module in [health, auth, player, clan]:
    for route in router_module.router.routes:
        if hasattr(route, "endpoint"):
            original_endpoint = route.endpoint

            # Wrap the endpoint to inject redis_client
            def make_wrapper(original):
                async def wrapper(*args, redis_client=None, **kwargs):
                    if redis_client is None:
                        redis_client = get_redis()
                    return await original(*args, redis_client=redis_client, **kwargs)

                wrapper.__name__ = original.__name__
                wrapper.__doc__ = original.__doc__
                return wrapper

            route.endpoint = make_wrapper(original_endpoint)


# Register all route modules
app.include_router(health.router, tags=["Health"])
app.include_router(auth.router, tags=["Authentication"])
app.include_router(player.router, tags=["Player"])
app.include_router(clan.router, tags=["Clan"])


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)
