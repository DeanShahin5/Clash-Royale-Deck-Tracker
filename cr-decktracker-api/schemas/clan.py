"""
Clan-related Pydantic schemas.
Request/response models for clan statistics and tracking.
"""
from typing import List, Optional
from pydantic import BaseModel


class MemberStats(BaseModel):
    """Statistics for a single clan member."""
    name: str
    tag: str
    donations: int
    donations_received: int
    war_attacks: int
    total_war_attacks: int
    battles: int
    wins: int
    losses: int
    ranked_battles: int
    ranked_wins: int
    ranked_losses: int
    ranked_avg_crowns: float
    ladder_battles: int
    ladder_wins: int
    ladder_losses: int
    ladder_avg_crowns: float
    last_seen: Optional[str] = None


class ClanStatsResp(BaseModel):
    """Response containing clan statistics for all members."""
    clan_name: str
    clan_tag: str
    members: List[MemberStats]
    time_period: str  # week/2weeks/month/all
    is_tracked: bool = False  # Whether clan is actively tracked
    tracking_since: Optional[str] = None


class TrackClanResp(BaseModel):
    """Response for starting clan tracking."""
    message: str
    clan_tag: str
    clan_name: str
    tracking_started: str
    snapshot_created: bool
