"""
Input validation utilities.
Functions to validate and sanitize user inputs for security.
"""
from fastapi import HTTPException
from config import (
    PASSWORD_MIN_LENGTH,
    PASSWORD_MAX_LENGTH,
    PASSWORD_SPECIAL_CHARS,
)


def validate_player_tag(tag: str) -> str:
    """
    Validate and sanitize player/clan tag.

    Format: #ABC123 (alphanumeric, max 15 chars after #)

    Security: Prevents injection attacks and malformed inputs.

    Args:
        tag: Raw player or clan tag (with or without # prefix)

    Returns:
        Validated tag with # prefix in uppercase

    Raises:
        HTTPException: If tag is invalid
    """
    if not tag:
        raise HTTPException(400, "Tag cannot be empty")

    # Remove leading # if present
    clean_tag = tag.lstrip('#')

    # Check length (max 15 chars)
    if len(clean_tag) > 15:
        raise HTTPException(400, "Tag is too long (max 15 characters)")

    # Check format (alphanumeric only)
    if not clean_tag.replace('0', '').replace('O', '').isalnum():
        raise HTTPException(400, "Tag must contain only letters and numbers")

    # Return with # prefix in uppercase
    return f"#{clean_tag.upper()}"


def validate_password(password: str) -> None:
    """
    Validate password meets security requirements.

    Requirements:
    - Min 8 characters, max 128
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    - At least one special character

    Security: Enforces strong passwords to prevent brute-force attacks.

    Args:
        password: User password to validate

    Raises:
        HTTPException: If password doesn't meet requirements
    """
    if len(password) < PASSWORD_MIN_LENGTH:
        raise HTTPException(400, f"Password must be at least {PASSWORD_MIN_LENGTH} characters long")

    if len(password) > PASSWORD_MAX_LENGTH:
        raise HTTPException(400, f"Password is too long (max {PASSWORD_MAX_LENGTH} characters)")

    if not any(c.isupper() for c in password):
        raise HTTPException(400, "Password must contain at least one uppercase letter")

    if not any(c.islower() for c in password):
        raise HTTPException(400, "Password must contain at least one lowercase letter")

    if not any(c.isdigit() for c in password):
        raise HTTPException(400, "Password must contain at least one number")

    # Check for special characters
    if not any(c in PASSWORD_SPECIAL_CHARS for c in password):
        raise HTTPException(400, "Password must contain at least one special character")


def sanitize_string(value: str, max_length: int = 255) -> str:
    """
    Sanitize string input by trimming whitespace and limiting length.

    Security: Prevents buffer overflow and injection attacks.

    Args:
        value: String to sanitize
        max_length: Maximum allowed length (default 255)

    Returns:
        Sanitized string
    """
    if not value:
        return ""

    # Strip whitespace
    clean = value.strip()

    # Truncate to max length
    if len(clean) > max_length:
        clean = clean[:max_length]

    return clean
