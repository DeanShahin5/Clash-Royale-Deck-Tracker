"""
Configuration settings loaded from environment variables.
Centralizes all application configuration for easy management.
"""
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Supercell API Configuration
SUPERCELL_API_TOKEN = os.getenv("SUPERCELL_API_TOKEN", "")
SUPERCELL_API_BASE_URL = "https://api.clashroyale.com/v1"

if not SUPERCELL_API_TOKEN:
    raise RuntimeError("Missing SUPERCELL_API_TOKEN in .env")

# Database Configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://localhost/decktracker")

# Redis Configuration
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")

# JWT Authentication
JWT_SECRET = os.getenv("JWT_SECRET", "your-secret-key-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_DAYS = 7

# CORS Configuration
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080").split(",")
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

# Cache Configuration (in seconds)
API_CACHE_TTL = 300  # 5 minutes
CLAN_STATS_CACHE_TTL = 300  # 5 minutes
BATTLE_LOG_CACHE_TTL = 600  # 10 minutes

# Rate Limiting
GENERAL_RATE_LIMIT = 100  # requests per hour
GENERAL_RATE_WINDOW = 3600  # 1 hour in seconds
AUTH_RATE_LIMIT = 5  # requests per minute
AUTH_RATE_WINDOW = 60  # 1 minute in seconds

# Security
BCRYPT_ROUNDS = 12  # Industry standard for password hashing

# Password Requirements
PASSWORD_MIN_LENGTH = 8
PASSWORD_MAX_LENGTH = 128
PASSWORD_SPECIAL_CHARS = "!@#$%^&*()_+-=[]{}|;:,.<>?"
