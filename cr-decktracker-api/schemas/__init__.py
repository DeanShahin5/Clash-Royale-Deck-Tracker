"""
Pydantic schemas package.
Exports all request/response models for API endpoints.
"""
from schemas.auth import RegisterReq, LoginReq, UpdateProfileReq, AuthResp
from schemas.player import (
    ResolveReq,
    ResolveByNameReq,
    ResolveResp,
    Deck,
    PredictResp,
    BattleInfo,
    PlayerStatsResp,
)
from schemas.clan import MemberStats, ClanStatsResp, TrackClanResp

__all__ = [
    # Auth
    "RegisterReq",
    "LoginReq",
    "UpdateProfileReq",
    "AuthResp",
    # Player
    "ResolveReq",
    "ResolveByNameReq",
    "ResolveResp",
    "Deck",
    "PredictResp",
    "BattleInfo",
    "PlayerStatsResp",
    # Clan
    "MemberStats",
    "ClanStatsResp",
    "TrackClanResp",
]
