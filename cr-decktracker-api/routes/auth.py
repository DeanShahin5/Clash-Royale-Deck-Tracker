"""
Authentication routes.
User registration, login, and profile management endpoints.
"""
from fastapi import APIRouter, HTTPException, Depends, Request
from sqlalchemy.orm import Session
from schemas.auth import RegisterReq, LoginReq, UpdateProfileReq, AuthResp
from models import User
from utils.validation import validate_player_tag, validate_password
from utils.auth import hash_password, verify_password, create_jwt_token
from utils.rate_limiting import require_auth_rate_limit
from dependencies import get_current_user, get_db_session

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=AuthResp)
async def register(
    req: RegisterReq,
    request: Request,
    db: Session = Depends(get_db_session),
    redis_client=None
):
    """
    Register a new user account.

    Rate limited: 5 attempts per minute per IP address.

    Validates:
    - Password strength requirements
    - Player/clan tag format (if provided)
    - Email uniqueness

    Returns JWT token upon successful registration.
    """
    # Check rate limit
    await require_auth_rate_limit(request, redis_client)

    # Validate password requirements
    validate_password(req.password)

    # Validate and sanitize player/clan tags if provided
    validated_player_tag = None
    validated_clan_tag = None

    if req.player_tag:
        validated_player_tag = validate_player_tag(req.player_tag)

    if req.clan_tag:
        validated_clan_tag = validate_player_tag(req.clan_tag)

    # Check if email already exists
    existing_user = db.query(User).filter_by(email=req.email).first()
    if existing_user:
        raise HTTPException(400, "Email already registered")

    # Create new user
    user = User(
        email=req.email,
        password_hash=hash_password(req.password),
        player_tag=validated_player_tag,
        clan_tag=validated_clan_tag
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # Generate JWT token
    token = create_jwt_token(user.email, user.player_tag)

    return {
        "token": token,
        "email": user.email,
        "player_tag": user.player_tag,
        "clan_tag": user.clan_tag
    }


@router.post("/login", response_model=AuthResp)
async def login(
    req: LoginReq,
    request: Request,
    db: Session = Depends(get_db_session),
    redis_client=None
):
    """
    Login with email and password.

    Rate limited: 5 attempts per minute per IP address.

    Returns JWT token upon successful authentication.
    """
    # Check rate limit
    await require_auth_rate_limit(request, redis_client)

    # Find user
    user = db.query(User).filter_by(email=req.email).first()
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(401, "Invalid email or password")

    # Generate JWT token
    token = create_jwt_token(user.email, user.player_tag)

    return {
        "token": token,
        "email": user.email,
        "player_tag": user.player_tag,
        "clan_tag": user.clan_tag
    }


@router.get("/me")
async def get_me(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db_session)
):
    """
    Get current user information.

    Requires: Valid JWT token in Authorization header.

    Returns user profile data.
    """
    user = db.query(User).filter_by(email=current_user["email"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    return {
        "email": user.email,
        "player_tag": user.player_tag,
        "clan_tag": user.clan_tag
    }


@router.put("/update-profile", response_model=AuthResp)
async def update_profile(
    req: UpdateProfileReq,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db_session)
):
    """
    Update user profile (player_tag and clan_tag).

    Requires: Valid JWT token in Authorization header.

    Returns new JWT token with updated information.
    """
    # Find user
    user = db.query(User).filter_by(email=current_user["email"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    # Validate and sanitize player/clan tags if provided
    validated_player_tag = None
    validated_clan_tag = None

    if req.player_tag is not None:
        if req.player_tag.strip():  # If not empty
            validated_player_tag = validate_player_tag(req.player_tag)

    if req.clan_tag is not None:
        if req.clan_tag.strip():  # If not empty
            validated_clan_tag = validate_player_tag(req.clan_tag)

    # Update user
    if req.player_tag is not None:
        user.player_tag = validated_player_tag
    if req.clan_tag is not None:
        user.clan_tag = validated_clan_tag

    db.commit()
    db.refresh(user)

    # Generate new token with updated info
    token = create_jwt_token(user.email, user.player_tag)

    return {
        "token": token,
        "email": user.email,
        "player_tag": user.player_tag,
        "clan_tag": user.clan_tag
    }
