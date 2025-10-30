"""
General helper utilities.
Reusable functions for common operations.
"""
import urllib.parse
from typing import List, Tuple
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from models import BattleLog


def enc_tag(tag: str) -> str:
    """
    Encode Clash Royale tag for URL usage.

    Decodes any incoming %23, ensures leading '#', then encodes once.

    Args:
        tag: Player or clan tag

    Returns:
        URL-encoded tag
    """
    tag = urllib.parse.unquote(tag)
    if not tag.startswith("#"):
        tag = "#" + tag
    return urllib.parse.quote(tag, safe="")


def canon(cards: List[dict]) -> Tuple[str, ...]:
    """
    Normalize deck to sorted tuple of card names.

    Used for identifying unique decks by creating a canonical representation.

    Args:
        cards: List of card dictionaries with 'name' field

    Returns:
        Sorted tuple of card names
    """
    return tuple(sorted(c["name"] for c in cards))


def calculate_wins_losses(battles: list, player_tag: str) -> Tuple[int, int]:
    """
    Calculate wins and losses from battle log.

    Only counts PvP battles (pathOfLegend, ladder, challenge, tournament).
    Skips 2v2 and other non-competitive modes.

    Args:
        battles: List of battle data from Supercell API
        player_tag: Player tag (currently unused but kept for future filtering)

    Returns:
        Tuple of (wins, losses)
    """
    wins = 0
    losses = 0

    for battle in battles:
        # Skip battles without team data
        if "team" not in battle or not battle["team"]:
            continue

        # Skip non-PvP battles
        battle_type = battle.get("type", "")
        if battle_type not in ["pathOfLegend", "ladder", "challenge", "tournament"]:
            continue

        try:
            # Get team and opponent data
            team = battle["team"][0] if battle["team"] else {}
            opponent = battle.get("opponent", [{}])[0] if battle.get("opponent") else {}

            team_crowns = team.get("crowns", 0)
            opponent_crowns = opponent.get("crowns", 0)

            # Determine win/loss
            if team_crowns > opponent_crowns:
                wins += 1
            elif opponent_crowns > team_crowns:
                losses += 1
            # Draws are not counted

        except (KeyError, IndexError, TypeError):
            continue

    return wins, losses


def calculate_mode_stats(battles: list, battle_type: str) -> dict:
    """
    Calculate statistics for a specific battle mode (ranked/ladder).

    Args:
        battles: List of battle data
        battle_type: Battle mode to filter for (e.g., "pathOfLegend", "trail")

    Returns:
        Dictionary with battles, wins, losses, and avg_crowns
    """
    mode_battles = 0
    mode_wins = 0
    mode_losses = 0
    total_crowns = 0

    for battle in battles:
        # Only count battles of the specified type
        if battle.get("type") != battle_type:
            continue

        # Skip battles without team data
        if "team" not in battle or not battle["team"]:
            continue

        try:
            team = battle["team"][0] if battle["team"] else {}
            opponent = battle.get("opponent", [{}])[0] if battle.get("opponent") else {}

            team_crowns = team.get("crowns", 0)
            opponent_crowns = opponent.get("crowns", 0)

            mode_battles += 1
            total_crowns += team_crowns

            # Determine win/loss
            if team_crowns > opponent_crowns:
                mode_wins += 1
            elif opponent_crowns > team_crowns:
                mode_losses += 1

        except (KeyError, IndexError, TypeError):
            continue

    avg_crowns = (total_crowns / mode_battles) if mode_battles > 0 else 0.0

    return {
        "battles": mode_battles,
        "wins": mode_wins,
        "losses": mode_losses,
        "avg_crowns": round(avg_crowns, 2)
    }


def save_battle_log(db_session_factory, player_tag: str, battles: list, deck_analysis: dict):
    """
    Save battle log to database.

    Args:
        db_session_factory: SQLAlchemy session factory
        player_tag: Player tag to save data for
        battles: Battle log data
        deck_analysis: Analyzed deck data (top 3 decks with confidence)
    """
    db = db_session_factory()
    try:
        log = BattleLog(
            player_tag=player_tag,
            battles=battles,
            deck_analysis=deck_analysis,
            fetched_at=datetime.utcnow()
        )
        db.merge(log)  # Insert or update
        db.commit()
        print(f"💾 Saved battle log for {player_tag} to database")
    finally:
        db.close()


def get_cached_battle_log(db_session_factory, player_tag: str, cache_minutes: int = 10) -> dict:
    """
    Get battle log from database if recent.

    Args:
        db_session_factory: SQLAlchemy session factory
        player_tag: Player tag to retrieve data for
        cache_minutes: Cache validity period in minutes (default 10)

    Returns:
        Dictionary with battles, deck_analysis, and cached flag, or None if not cached
    """
    db = db_session_factory()
    try:
        log = db.query(BattleLog).filter_by(player_tag=player_tag).first()
        if log and (datetime.utcnow() - log.fetched_at) < timedelta(minutes=cache_minutes):
            print(f"✅ Database cache HIT for {player_tag}")
            return {
                "battles": log.battles,
                "deck_analysis": log.deck_analysis,
                "cached": True
            }
        print(f"❌ Database cache MISS for {player_tag}")
        return None
    finally:
        db.close()
