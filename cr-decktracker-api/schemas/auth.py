"""
Authentication-related Pydantic schemas.
Request/response models for user registration, login, and profile updates.
"""
from typing import Optional
from pydantic import BaseModel, EmailStr


class RegisterReq(BaseModel):
    """Request schema for user registration."""
    email: EmailStr
    password: str
    player_tag: Optional[str] = None
    clan_tag: Optional[str] = None


class LoginReq(BaseModel):
    """Request schema for user login."""
    email: EmailStr
    password: str


class UpdateProfileReq(BaseModel):
    """Request schema for updating user profile."""
    player_tag: Optional[str] = None
    clan_tag: Optional[str] = None


class AuthResp(BaseModel):
    """Response schema for authentication endpoints (login/register)."""
    token: str
    email: str
    player_tag: Optional[str] = None
    clan_tag: Optional[str] = None
