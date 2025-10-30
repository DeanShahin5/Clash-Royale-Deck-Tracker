"""
Player-related Pydantic schemas.
Request/response models for player resolution, stats, and deck predictions.
"""
from typing import List, Optional
from pydantic import BaseModel


class ResolveReq(BaseModel):
    """Request to resolve player by name within a clan (using clan tag)."""
    player_name: str
    clan_tag: str


class ResolveByNameReq(BaseModel):
    """Request to resolve player by name within a clan (using clan name)."""
    player_name: str
    clan_name: str


class ResolveResp(BaseModel):
    """Response containing resolved player information."""
    player_tag: str
    name: str
    confidence: int  # Fuzzy match confidence score (0-100)


class Deck(BaseModel):
    """Represents a deck with its usage frequency."""
    deck: List[str]  # List of card names
    confidence: float  # Usage frequency (0.0-1.0)


class PredictResp(BaseModel):
    """Response containing predicted decks for a player."""
    player_tag: str
    top3: List[Deck]  # Top 3 most used decks
    cached: bool = False


class BattleInfo(BaseModel):
    """Detailed information about a single battle."""
    type: str  # Battle type (pathOfLegend, ladder, etc.)
    battle_time: str
    result: Optional[str] = None  # win/loss/draw
    crowns: int
    opponent_crowns: int
    deck: List[str]  # Cards used in this battle
    arena: Optional[str] = None
    player_trophies: Optional[int] = None
    opponent_name: Optional[str] = None
    opponent_trophies: Optional[int] = None


class PlayerStatsResp(BaseModel):
    """Comprehensive player statistics response."""
    player_tag: str
    name: str
    trophies: int
    best_trophies: int
    level: int
    arena: str
    clan: Optional[str] = None
    clan_tag: Optional[str] = None
    total_battles: int
    wins: int
    losses: int
    win_rate: float
    recent_battles: List[BattleInfo]
    top_decks: List[Deck]
