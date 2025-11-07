"""
Player routes.
Player resolution, deck prediction, and statistics endpoints.
"""
from fastapi import APIRouter, HTTPException, Request
from schemas.player import (
    ResolveReq,
    ResolveByNameReq,
    ResolveResp,
    PredictResp,
    PlayerStatsResp,
)
from services.supercell_api import SupercellAPIService
from services import player_service
from utils.validation import validate_player_tag, sanitize_string
from utils.rate_limiting import check_rate_limit
from database import SessionLocal

router = APIRouter(tags=["Player"])


@router.post("/resolve_player", response_model=ResolveResp)
async def resolve_player(req: ResolveReq, request: Request, redis_client=None):
    """
    Find player's tag by fuzzy matching their name inside a clan (by clan tag).

    Uses fuzzy matching with 70% confidence threshold.

    Rate limited: 100 requests per hour per IP.
    """
    # Validate clan tag
    validated_clan_tag = validate_player_tag(req.clan_tag)

    # Sanitize player name
    clean_player_name = sanitize_string(req.player_name, max_length=50)
    if not clean_player_name:
        raise HTTPException(400, "Player name cannot be empty")

    # Rate limiting
    client_ip = request.client.host
    if not await check_rate_limit(redis_client, client_ip):
        raise HTTPException(status_code=429, detail="Rate limit exceeded. Try again in an hour.")

    # Use service layer
    api_service = SupercellAPIService(redis_client)
    return await player_service.resolve_player_by_clan_tag(
        clean_player_name,
        validated_clan_tag,
        api_service
    )


@router.post("/resolve_player_by_name", response_model=ResolveResp)
async def resolve_player_by_name(req: ResolveByNameReq, request: Request, redis_client=None):
    """
    Find player by searching clan name, then fuzzy matching player within clan.

    Searches up to 10 clans matching the provided name.
    Uses fuzzy matching with 70% confidence threshold.

    Rate limited: 100 requests per hour per IP.
    """
    # Sanitize inputs
    clean_player_name = sanitize_string(req.player_name, max_length=50)
    clean_clan_name = sanitize_string(req.clan_name, max_length=50)

    if not clean_player_name:
        raise HTTPException(400, "Player name cannot be empty")
    if not clean_clan_name:
        raise HTTPException(400, "Clan name cannot be empty")

    # Rate limiting
    client_ip = request.client.host
    if not await check_rate_limit(redis_client, client_ip):
        raise HTTPException(status_code=429, detail="Rate limit exceeded. Try again in an hour.")

    # Use service layer
    api_service = SupercellAPIService(redis_client)
    return await player_service.resolve_player_by_clan_name(
        clean_player_name,
        clean_clan_name,
        api_service
    )


@router.get("/predict/{player_tag}", response_model=PredictResp)
async def predict(
    player_tag: str,
    request: Request,
    redis_client=None,
    game_mode: str = "ranked"
):
    """
    Fetch recent battles and return top-3 most frequent decks for a player.

    Game mode options:
    - "ladder" - Trophy Road battles (type == "trail")
    - "ranked" - Path of Legend battles (type == "pathOfLegend")
    - "all" - All battle types combined

    Results are cached for 10 minutes.

    Rate limited: 100 requests per hour per IP.
    """
    # Validate player tag
    validated_player_tag = validate_player_tag(player_tag)

    # Rate limiting
    client_ip = request.client.host
    if not await check_rate_limit(redis_client, client_ip):
        raise HTTPException(status_code=429, detail="Rate limit exceeded. Try again in an hour.")

    # Use service layer
    api_service = SupercellAPIService(redis_client)
    return await player_service.predict_player_decks(
        validated_player_tag,
        game_mode,
        api_service,
        SessionLocal
    )


@router.get("/player/{player_tag}/stats", response_model=PlayerStatsResp)
async def get_player_stats(player_tag: str, request: Request, redis_client=None):
    """
    Get detailed player statistics including recent battles and top decks.

    Returns:
    - Player profile (trophies, level, arena, clan)
    - Win/loss statistics
    - Last 10 battles with details
    - Top 3 most used decks

    Rate limited: 100 requests per hour per IP.
    """
    # Validate player tag
    validated_player_tag = validate_player_tag(player_tag)

    # Rate limiting
    client_ip = request.client.host
    if not await check_rate_limit(redis_client, client_ip):
        raise HTTPException(status_code=429, detail="Rate limit exceeded. Try again in an hour.")

    # Use service layer
    api_service = SupercellAPIService(redis_client)

    try:
        return await player_service.get_player_stats(validated_player_tag, api_service)
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error in get_player_stats: {e}")
        raise HTTPException(
            status_code=500,
            detail="An error occurred while fetching player stats. Please try again later."
        )


@router.get("/debug/battlelog/{player_tag}")
async def debug_battlelog(player_tag: str, redis_client=None):
    """
    Return raw battle log for debugging.

    Development/testing endpoint to inspect raw API data.
    """
    from utils.helpers import enc_tag

    api_service = SupercellAPIService(redis_client)
    battles = await api_service.get(f"/players/{enc_tag(player_tag)}/battlelog")

    return {
        "raw_battles": battles,
        "count": len(battles) if isinstance(battles, list) else len(battles.get("items", []))
    }
