"""
Clan service layer.
Business logic for clan tracking, statistics, and snapshot management.
"""
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from models import TrackedClan, ClanMemberSnapshot
from services.supercell_api import SupercellAPIService
from utils.helpers import enc_tag, calculate_wins_losses


async def create_clan_snapshot(
    clan_tag: str,
    db: Session,
    api_service: SupercellAPIService
) -> bool:
    """
    Create a snapshot of all clan member stats for today.

    Args:
        clan_tag: Clan tag to snapshot
        db: Database session
        api_service: Supercell API service instance

    Returns:
        True if snapshot created, False if already exists
    """
    try:
        today = datetime.utcnow().date()

        # Check if snapshot already exists for today
        existing = db.query(ClanMemberSnapshot).filter_by(
            clan_tag=clan_tag,
            snapshot_date=today
        ).first()

        if existing:
            print(f"Snapshot already exists for {clan_tag} on {today}")
            return False

        # Fetch clan members
        members_data = await api_service.get(f"/clans/{enc_tag(clan_tag)}/members")
        members = members_data.get("items", [])

        # Fetch river race data for medals/war attacks
        try:
            river_race_data = await api_service.get(f"/clans/{enc_tag(clan_tag)}/riverracelog")
            river_race = river_race_data.get("items", [])
        except:
            river_race = []

        # Create snapshot for each member
        for member in members:
            member_tag = member["tag"]

            # Calculate war stats from river race
            medals = 0
            war_attacks = 0
            total_war_attacks = 0

            for race in river_race[:5]:  # Last 5 races
                if "standings" in race:
                    for standing in race["standings"]:
                        if standing.get("clan", {}).get("tag") == clan_tag:
                            participants = standing.get("clan", {}).get("participants", [])
                            for p in participants:
                                if p.get("tag") == member_tag:
                                    medals += p.get("fame", 0)
                                    war_attacks += p.get("decksUsed", 0)
                                    total_war_attacks += 4

            # Fetch battle count and calculate wins/losses
            try:
                battle_log = await api_service.get(f"/players/{enc_tag(member_tag)}/battlelog")
                battles = battle_log if isinstance(battle_log, list) else battle_log.get("items", [])
                battle_count = len(battles)
                wins, losses = calculate_wins_losses(battles, member_tag)
            except:
                battle_count = 0
                wins = 0
                losses = 0

            # Create snapshot
            snapshot = ClanMemberSnapshot(
                clan_tag=clan_tag,
                player_tag=member_tag,
                player_name=member["name"],
                donations_given=member.get("donations", 0),
                donations_received=member.get("donationsReceived", 0),
                war_attacks=war_attacks,
                total_war_attacks=total_war_attacks,
                medals=medals,
                battles=battle_count,
                wins=wins,
                losses=losses,
                snapshot_date=today
            )
            db.add(snapshot)

        db.commit()
        print(f"✅ Created snapshot for {len(members)} members in clan {clan_tag}")
        return True

    except Exception as e:
        print(f"Error creating snapshot for {clan_tag}: {e}")
        db.rollback()
        return False


def get_historical_stats(clan_tag: str, time_period: str, db: Session) -> list:
    """
    Get historical stats from snapshots with deltas.

    Calculates the difference between the latest snapshot and a snapshot
    from the start of the time period.

    Args:
        clan_tag: Clan tag to get stats for
        time_period: Time period (week/2weeks/month/all)
        db: Database session

    Returns:
        List of member stats with deltas, or None if no data
    """
    today = datetime.utcnow().date()

    # Calculate date range
    days_ago = {
        "week": 7,
        "2weeks": 14,
        "month": 30,
        "all": 9999
    }.get(time_period, 7)

    start_date = today - timedelta(days=days_ago)

    # Get latest snapshot for each member
    latest_snapshots = db.query(ClanMemberSnapshot).filter(
        ClanMemberSnapshot.clan_tag == clan_tag,
        ClanMemberSnapshot.snapshot_date == today
    ).all()

    if not latest_snapshots:
        return None

    # Get snapshots from start_date
    old_snapshots = db.query(ClanMemberSnapshot).filter(
        ClanMemberSnapshot.clan_tag == clan_tag,
        ClanMemberSnapshot.snapshot_date >= start_date,
        ClanMemberSnapshot.snapshot_date < today
    ).all()

    # Create lookup for old snapshots
    old_lookup = {}
    for snap in old_snapshots:
        if snap.player_tag not in old_lookup:
            old_lookup[snap.player_tag] = snap

    # Calculate deltas
    results = []
    for latest in latest_snapshots:
        old = old_lookup.get(latest.player_tag)

        if old:
            # Calculate deltas
            donations_delta = latest.donations_given - old.donations_given
            donations_received_delta = latest.donations_received - old.donations_received
            war_attacks_delta = latest.war_attacks - old.war_attacks
            medals_delta = latest.medals - old.medals
            battles_delta = latest.battles - old.battles
            wins_delta = latest.wins - old.wins
            losses_delta = latest.losses - old.losses
        else:
            # No historical data, use current values
            donations_delta = latest.donations_given
            donations_received_delta = latest.donations_received
            war_attacks_delta = latest.war_attacks
            medals_delta = latest.medals
            battles_delta = latest.battles
            wins_delta = latest.wins
            losses_delta = latest.losses

        results.append({
            "name": latest.player_name,
            "tag": latest.player_tag,
            "donations": donations_delta,
            "donations_received": donations_received_delta,
            "war_attacks": war_attacks_delta,
            "total_war_attacks": latest.total_war_attacks,
            "medals": medals_delta,
            "battles": battles_delta,
            "wins": wins_delta,
            "losses": losses_delta,
            "last_seen": None
        })

    return results
