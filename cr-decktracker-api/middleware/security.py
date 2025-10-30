"""
Security middleware for HTTP headers and CORS.
Adds security headers to all responses and configures CORS.
"""
import os
from fastapi import Request
from fastapi.middleware.cors import CORSMiddleware
from config import ALLOWED_ORIGINS, ENVIRONMENT


def setup_cors(app):
    """
    Configure CORS middleware for the FastAPI application.
    In production, restricts to specific origins. In dev, allows all origins.
    """
    app.add_middleware(
        CORSMiddleware,
        allow_origins=ALLOWED_ORIGINS if ENVIRONMENT == "production" else ["*"],
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Requested-With"],
        max_age=600  # Cache preflight requests for 10 minutes
    )


async def add_security_headers(request: Request, call_next):
    """
    Middleware that adds security headers to all HTTP responses.

    Security headers include:
    - Content Security Policy: Restricts resource loading
    - X-Frame-Options: Prevents clickjacking
    - X-Content-Type-Options: Prevents MIME sniffing
    - X-XSS-Protection: Enables browser XSS protection
    - Strict-Transport-Security: Enforces HTTPS (production only)
    - Referrer-Policy: Controls referrer information
    - Permissions-Policy: Restricts browser features
    """
    response = await call_next(request)

    # Content Security Policy - Restrict resource loading
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "
        "script-src 'self' 'unsafe-inline'; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: https:; "
        "font-src 'self' data:; "
        "connect-src 'self' https://api.clashroyale.com; "
        "frame-ancestors 'none';"
    )

    # Prevent clickjacking attacks
    response.headers["X-Frame-Options"] = "DENY"

    # Prevent MIME type sniffing
    response.headers["X-Content-Type-Options"] = "nosniff"

    # Enable browser XSS protection
    response.headers["X-XSS-Protection"] = "1; mode=block"

    # Enforce HTTPS in production (HSTS)
    if ENVIRONMENT == "production":
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

    # Referrer policy
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

    # Permissions policy (restrict browser features)
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"

    return response
