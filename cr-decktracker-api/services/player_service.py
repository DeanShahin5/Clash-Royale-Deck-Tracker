"""
Player service layer.
Business logic for player resolution, deck prediction, and statistics.
"""
from typing import Tuple
from rapidfuzz import process, fuzz
from fastapi import HTTPException
from services.supercell_api import SupercellAPIService
from utils.helpers import enc_tag, canon, calculate_wins_losses, calculate_mode_stats
from database import SessionLocal


async def resolve_player_by_clan_tag(
    player_name: str,
    clan_tag: str,
    api_service: SupercellAPIService
) -> dict:
    """
    Find player's tag by fuzzy matching their name inside a clan (by clan tag).

    Args:
        player_name: Name of player to find
        clan_tag: Clan tag to search within
        api_service: Supercell API service instance

    Returns:
        Dictionary with player_tag, name, and confidence score

    Raises:
        HTTPException: If no match found or clan has no members
    """
    data = await api_service.get(f"/clans/{enc_tag(clan_tag)}/members")

    members = data.get("items", [])
    if not members:
        raise HTTPException(404, "No members found for that clan tag")

    names = [m["name"] for m in members]
    match = process.extractOne(player_name, names, scorer=fuzz.WRatio)

    if not match or match[1] < 70:
        raise HTTPException(404, f"No close match found. Best was: {match}")

    chosen = next(m for m in members if m["name"] == match[0])
    return {
        "player_tag": chosen["tag"],
        "name": chosen["name"],
        "confidence": int(match[1])
    }


async def resolve_player_by_clan_name(
    player_name: str,
    clan_name: str,
    api_service: SupercellAPIService
) -> dict:
    """
    Find player by searching clan name, then fuzzy matching player within clan.

    Args:
        player_name: Name of player to find
        clan_name: Clan name to search for
        api_service: Supercell API service instance

    Returns:
        Dictionary with player_tag, name, and confidence score

    Raises:
        HTTPException: If player not found in any matching clan
    """
    clan_search = await api_service.get("/clans", params={"name": clan_name, "limit": 10})

    clans = clan_search.get("items", [])
    if not clans:
        raise HTTPException(404, f"No clans found matching '{clan_name}'")

    print(f"Found {len(clans)} clans matching '{clan_name}'")

    # Search through each clan for the player
    for clan in clans:
        try:
            members_data = await api_service.get(f"/clans/{enc_tag(clan['tag'])}/members")
            members = members_data.get("items", [])
            names = [m["name"] for m in members]

            match = process.extractOne(player_name, names, scorer=fuzz.WRatio)
            if match and match[1] >= 70:
                chosen = next(m for m in members if m["name"] == match[0])
                print(f"Found {chosen['name']} in clan {clan['name']} ({clan['tag']})")
                return {
                    "player_tag": chosen["tag"],
                    "name": chosen["name"],
                    "confidence": int(match[1])
                }
        except Exception as e:
            print(f"Error searching clan {clan.get('name', 'unknown')}: {e}")
            continue

    raise HTTPException(404, f"Player '{player_name}' not found in any clan named '{clan_name}'")


async def predict_player_decks(
    player_tag: str,
    game_mode: str,
    api_service: SupercellAPIService,
    db_session_factory
) -> dict:
    """
    Fetch recent battles and return top-3 most frequent decks for a player.

    Supports filtering by game mode (ladder/ranked/all).

    Args:
        player_tag: Player tag to analyze
        game_mode: Game mode filter (ladder/ranked/all)
        api_service: Supercell API service instance
        db_session_factory: Database session factory for caching

    Returns:
        Dictionary with player_tag, top3 decks, and cached flag

    Raises:
        HTTPException: If invalid game mode or no battles found
    """
    from utils.helpers import save_battle_log, get_cached_battle_log

    # Validate game mode
    valid_modes = ["ladder", "ranked", "all"]
    if game_mode not in valid_modes:
        raise HTTPException(400, f"Invalid game mode. Must be one of: {', '.join(valid_modes)}")

    # Check database cache first (cache key includes game mode)
    cache_key = f"{player_tag}:{game_mode}"
    cached_data = get_cached_battle_log(db_session_factory, cache_key)
    if cached_data:
        return {
            "player_tag": player_tag,
            "top3": cached_data["deck_analysis"]["top3"],
            "cached": True
        }

    # Fetch battle log from API
    response = await api_service.get(f"/players/{enc_tag(player_tag)}/battlelog")
    battles = response if isinstance(response, list) else response.get("items", [])

    print(f"Fetched {len(battles)} battles for {player_tag}")

    # Filter battles by game mode
    if game_mode == "ladder":
        filtered_battles = [b for b in battles if b.get("type") == "trail"]  # Trophy Road
        mode_name = "Ladder (Trophy Road)"
    elif game_mode == "ranked":
        filtered_battles = [b for b in battles if b.get("type") == "pathOfLegend"]
        mode_name = "Ranked (Path of Legend)"
    else:  # all
        filtered_battles = battles
        mode_name = "All Modes"

    print(f"Found {len(filtered_battles)} {mode_name} battles out of {len(battles)} total")

    # Check if any battles found for this mode
    if not filtered_battles:
        raise HTTPException(
            404,
            f"No {mode_name} battles found for this player. Try another mode."
        )

    # Count deck frequencies
    counts: dict[Tuple[str,...], int] = {}
    for i, b in enumerate(filtered_battles):
        try:
            if "team" not in b or not b["team"]:
                continue

            player_cards = b["team"][0]["cards"]
            deck_key = canon(player_cards)
            counts[deck_key] = counts.get(deck_key, 0) + 1
        except Exception as e:
            print(f"Battle {i}: error {e}")

    print(f"Total unique decks found: {len(counts)}")

    # Check if we have any valid decks
    if not counts:
        raise HTTPException(
            404,
            f"No valid deck data found in {mode_name} battles for this player."
        )

    # Calculate top 3 decks with confidence scores
    total = sum(counts.values()) or 1
    top3 = sorted(counts.items(), key=lambda kv: kv[1], reverse=True)[:3]
    decks = [{"deck": list(deck), "confidence": round(n/total, 2)} for deck, n in top3]

    # Save to database
    deck_analysis = {"top3": decks, "game_mode": game_mode}
    save_battle_log(db_session_factory, cache_key, filtered_battles, deck_analysis)

    return {
        "player_tag": player_tag,
        "top3": decks,
        "cached": False
    }


async def get_player_stats(player_tag: str, api_service: SupercellAPIService) -> dict:
    """
    Get comprehensive player statistics including recent battles and top decks.

    Args:
        player_tag: Player tag to get stats for
        api_service: Supercell API service instance

    Returns:
        Dictionary with complete player stats

    Raises:
        HTTPException: On API errors
    """
    # Fetch player data
    player_data = await api_service.get(f"/players/{enc_tag(player_tag)}")

    # Fetch battle log
    battle_log = await api_service.get(f"/players/{enc_tag(player_tag)}/battlelog")
    battles = battle_log if isinstance(battle_log, list) else battle_log.get("items", [])

    # Calculate wins and losses from all battles
    total_wins, total_losses = calculate_wins_losses(battles, player_tag)
    total_battles = total_wins + total_losses
    win_rate = (total_wins / total_battles * 100) if total_battles > 0 else 0

    # Get recent battles (last 10)
    recent_battles = []
    for battle in battles[:10]:
        if "team" in battle and battle["team"]:
            team = battle["team"][0]
            opponent = battle.get("opponent", [{}])[0] if battle.get("opponent") else {}

            team_crowns = team.get("crowns", 0)
            opponent_crowns = opponent.get("crowns", 0)

            result = None
            if team_crowns > opponent_crowns:
                result = "win"
            elif opponent_crowns > team_crowns:
                result = "loss"
            else:
                result = "draw"

            deck_cards = [card["name"] for card in team.get("cards", [])]

            recent_battles.append({
                "type": battle.get("type", "unknown"),
                "battle_time": battle.get("battleTime", ""),
                "result": result,
                "crowns": team_crowns,
                "opponent_crowns": opponent_crowns,
                "deck": deck_cards,
                "arena": battle.get("arena", {}).get("name"),
                "player_trophies": team.get("startingTrophies"),
                "opponent_name": opponent.get("name"),
                "opponent_trophies": opponent.get("startingTrophies")
            })

    # Calculate top decks (from ranked battles only)
    ranked_battles = [b for b in battles if b.get("type") in ["pathOfLegend", "ladder"]]
    counts: dict[Tuple[str,...], int] = {}
    for b in ranked_battles:
        try:
            if "team" not in b or not b["team"]:
                continue
            player_cards = b["team"][0]["cards"]
            deck_key = canon(player_cards)
            counts[deck_key] = counts.get(deck_key, 0) + 1
        except Exception:
            continue

    total = sum(counts.values()) or 1
    top3 = sorted(counts.items(), key=lambda kv: kv[1], reverse=True)[:3]
    top_decks = [{"deck": list(deck), "confidence": round(n/total, 2)} for deck, n in top3]

    # Get clan info
    clan_name = player_data.get("clan", {}).get("name")
    clan_tag = player_data.get("clan", {}).get("tag")

    return {
        "player_tag": player_tag,
        "name": player_data.get("name", "Unknown"),
        "trophies": player_data.get("trophies", 0),
        "best_trophies": player_data.get("bestTrophies", 0),
        "level": player_data.get("expLevel", 1),
        "arena": player_data.get("arena", {}).get("name", "Unknown Arena"),
        "clan": clan_name,
        "clan_tag": clan_tag,
        "total_battles": total_battles,
        "wins": total_wins,
        "losses": total_losses,
        "win_rate": round(win_rate, 1),
        "recent_battles": recent_battles,
        "top_decks": top_decks
    }
