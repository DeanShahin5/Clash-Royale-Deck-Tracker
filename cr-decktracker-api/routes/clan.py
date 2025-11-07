"""
Clan routes.
Clan tracking, statistics, and snapshot management endpoints.
"""
import json
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, Request, Depends
from sqlalchemy.orm import Session
from schemas.clan import ClanStatsResp, TrackClanResp
from models import User, TrackedClan
from services.supercell_api import SupercellAPIService
from services import clan_service
from utils.validation import validate_player_tag
from utils.rate_limiting import check_rate_limit
from utils.helpers import enc_tag, calculate_wins_losses, calculate_mode_stats
from dependencies import get_current_user, get_db_session
from config import CLAN_STATS_CACHE_TTL

router = APIRouter(prefix="/clan", tags=["Clan"])


@router.post("/{clan_tag}/track", response_model=TrackClanResp)
async def start_tracking_clan(
    clan_tag: str,
    redis_client=None,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db_session)
):
    """
    Start tracking a clan's statistics.

    Requires: Valid JWT token in Authorization header.

    Creates initial snapshot if tracking starts successfully.
    """
    # Validate clan tag
    validated_clan_tag = validate_player_tag(clan_tag)

    # Check if clan is already tracked
    tracked = db.query(TrackedClan).filter_by(clan_tag=validated_clan_tag).first()

    if tracked:
        return {
            "message": "Clan is already being tracked",
            "clan_tag": tracked.clan_tag,
            "clan_name": tracked.clan_name,
            "tracking_started": tracked.tracking_started.isoformat(),
            "snapshot_created": False
        }

    # Fetch clan info to get name
    api_service = SupercellAPIService(redis_client)
    clan_data = await api_service.get(f"/clans/{enc_tag(validated_clan_tag)}")
    clan_name = clan_data.get("name", "Unknown")

    # Get user ID
    user = db.query(User).filter_by(email=current_user["email"]).first()
    user_id = user.id if user else None

    # Create tracked clan entry
    tracked_clan = TrackedClan(
        clan_tag=validated_clan_tag,
        clan_name=clan_name,
        tracked_by_user_id=user_id,
        is_active=True
    )
    db.add(tracked_clan)
    db.commit()
    db.refresh(tracked_clan)

    # Create initial snapshot
    snapshot_created = await clan_service.create_clan_snapshot(
        validated_clan_tag,
        db,
        api_service
    )

    return {
        "message": "Clan tracking started successfully",
        "clan_tag": validated_clan_tag,
        "clan_name": clan_name,
        "tracking_started": tracked_clan.tracking_started.isoformat(),
        "snapshot_created": snapshot_created
    }


@router.get("/{clan_tag}/tracking-status")
async def get_tracking_status(clan_tag: str, db: Session = Depends(get_db_session)):
    """
    Check if a clan is being tracked.

    Returns tracking status and start date if applicable.
    """
    # Validate clan tag
    validated_clan_tag = validate_player_tag(clan_tag)

    tracked = db.query(TrackedClan).filter_by(
        clan_tag=validated_clan_tag,
        is_active=True
    ).first()

    if not tracked:
        return {
            "is_tracked": False,
            "tracking_since": None,
            "clan_name": None
        }

    return {
        "is_tracked": True,
        "tracking_since": tracked.tracking_started.isoformat(),
        "clan_name": tracked.clan_name
    }


@router.post("/{clan_tag}/snapshot")
async def create_snapshot(
    clan_tag: str,
    redis_client=None,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db_session)
):
    """
    Manually create a snapshot for a tracked clan.

    Requires: Valid JWT token in Authorization header.

    Creates a daily snapshot of all member statistics.
    Only one snapshot per day is allowed.
    """
    # Validate clan tag
    validated_clan_tag = validate_player_tag(clan_tag)

    # Check if clan is tracked
    tracked = db.query(TrackedClan).filter_by(
        clan_tag=validated_clan_tag,
        is_active=True
    ).first()

    if not tracked:
        raise HTTPException(404, "Clan is not being tracked")

    # Create snapshot
    api_service = SupercellAPIService(redis_client)
    created = await clan_service.create_clan_snapshot(validated_clan_tag, db, api_service)

    return {
        "message": "Snapshot created" if created else "Snapshot already exists for today",
        "created": created,
        "clan_tag": clan_tag,
        "date": datetime.utcnow().date().isoformat()
    }


@router.get("/{clan_tag}/stats", response_model=ClanStatsResp)
async def get_clan_stats(
    clan_tag: str,
    redis_client=None,
    time_period: str = "week",
    request: Request = None
):
    """
    Get clan member statistics with time period filter.

    Uses LIVE data from Supercell API (not historical snapshots).

    Time period options:
    - 'week' - Last 7 days
    - '2weeks' - Last 14 days
    - 'month' - Last 30 days
    - 'all' - All available battles

    Results are cached for 5 minutes.

    Rate limited: 100 requests per hour per IP.
    """
    try:
        # Validate clan tag
        validated_clan_tag = validate_player_tag(clan_tag)

        # Validate time period
        valid_periods = ["week", "2weeks", "month", "all"]
        if time_period not in valid_periods:
            raise HTTPException(
                400,
                f"Invalid time period. Must be one of: {', '.join(valid_periods)}"
            )

        # Rate limiting
        if request:
            client_ip = request.client.host
            if not await check_rate_limit(redis_client, client_ip):
                raise HTTPException(
                    status_code=429,
                    detail="Rate limit exceeded. Try again in an hour."
                )

        # Create cache key
        cache_key = f"clan_stats:{validated_clan_tag}:{time_period}"

        # Check Redis cache
        cached = await redis_client.get(cache_key)
        if cached:
            print(f"✅ Clan stats cache HIT: {validated_clan_tag} - {time_period}")
            return json.loads(cached)

        print(f"❌ Clan stats cache MISS: {validated_clan_tag} - {time_period}")

        # Fetch data from API
        api_service = SupercellAPIService(redis_client)

        # Fetch clan info
        clan_data = await api_service.get(f"/clans/{enc_tag(validated_clan_tag)}")
        clan_name = clan_data.get("name", "Unknown")

        # Fetch clan members
        members_data = await api_service.get(f"/clans/{enc_tag(validated_clan_tag)}/members")
        members = members_data.get("items", [])

        # Fetch river race log (for medals and attacks)
        try:
            river_race_data = await api_service.get(f"/clans/{enc_tag(validated_clan_tag)}/riverracelog")
            river_race = river_race_data.get("items", [])
        except:
            river_race = []

        # Calculate time filter (days)
        days_filter = {
            "week": 7,
            "2weeks": 14,
            "month": 30,
            "all": 9999
        }.get(time_period, 7)

        cutoff_date = datetime.utcnow() - timedelta(days=days_filter)

        # Process each member
        member_stats_list = []
        for member in members:
            member_tag = member["tag"]

            try:
                # Fetch player details
                player_data = await api_service.get(f"/players/{enc_tag(member_tag)}")

                # Fetch battle log
                battle_log = await api_service.get(f"/players/{enc_tag(member_tag)}/battlelog")
                battles = battle_log if isinstance(battle_log, list) else battle_log.get("items", [])

                # Filter battles by time period
                filtered_battles = []
                for battle in battles:
                    if "battleTime" in battle:
                        battle_time = datetime.strptime(battle["battleTime"], "%Y%m%dT%H%M%S.%fZ")
                        if battle_time >= cutoff_date:
                            filtered_battles.append(battle)

                # Calculate wins and losses
                wins, losses = calculate_wins_losses(filtered_battles, member_tag)

                # Calculate ranked (Path of Legend) stats
                ranked_stats = calculate_mode_stats(filtered_battles, "pathOfLegend")

                # Calculate ladder stats (Trophy Road uses "trail" type)
                ladder_stats = calculate_mode_stats(filtered_battles, "trail")

                # Count war attacks in river race
                war_attacks = 0
                total_war_attacks = 0

                for race in river_race[:5]:  # Last 5 races
                    if "standings" in race:
                        for standing in race["standings"]:
                            if standing.get("clan", {}).get("tag") == validated_clan_tag:
                                participants = standing.get("clan", {}).get("participants", [])
                                for p in participants:
                                    if p.get("tag") == member_tag:
                                        war_attacks += p.get("decksUsed", 0)
                                        total_war_attacks += 4  # Max 4 attacks per race

                member_stats_list.append({
                    "name": member["name"],
                    "tag": member_tag,
                    "donations": member.get("donations", 0),
                    "donations_received": member.get("donationsReceived", 0),
                    "war_attacks": war_attacks,
                    "total_war_attacks": total_war_attacks,
                    "battles": len(filtered_battles),
                    "wins": wins,
                    "losses": losses,
                    "ranked_battles": ranked_stats["battles"],
                    "ranked_wins": ranked_stats["wins"],
                    "ranked_losses": ranked_stats["losses"],
                    "ranked_avg_crowns": ranked_stats["avg_crowns"],
                    "ladder_battles": ladder_stats["battles"],
                    "ladder_wins": ladder_stats["wins"],
                    "ladder_losses": ladder_stats["losses"],
                    "ladder_avg_crowns": ladder_stats["avg_crowns"],
                    "last_seen": player_data.get("lastSeen", None)
                })

            except Exception as e:
                print(f"Error fetching stats for {member_tag}: {e}")
                # Add with zero stats if error
                member_stats_list.append({
                    "name": member["name"],
                    "tag": member_tag,
                    "donations": member.get("donations", 0),
                    "donations_received": member.get("donationsReceived", 0),
                    "war_attacks": 0,
                    "total_war_attacks": 0,
                    "battles": 0,
                    "wins": 0,
                    "losses": 0,
                    "ranked_battles": 0,
                    "ranked_wins": 0,
                    "ranked_losses": 0,
                    "ranked_avg_crowns": 0.0,
                    "ladder_battles": 0,
                    "ladder_wins": 0,
                    "ladder_losses": 0,
                    "ladder_avg_crowns": 0.0,
                    "last_seen": None
                })

        response_data = {
            "clan_name": clan_name,
            "clan_tag": validated_clan_tag,
            "members": member_stats_list,
            "time_period": time_period,
            "is_tracked": False,
            "tracking_since": None
        }

        # Cache for 5 minutes
        await redis_client.setex(cache_key, CLAN_STATS_CACHE_TTL, json.dumps(response_data))

        return response_data

    except HTTPException:
        # Re-raise HTTPExceptions as-is
        raise
    except Exception as e:
        print(f"❌ Unexpected error in get_clan_stats: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail="An error occurred while fetching clan stats. Please try again later."
        )
