"""
Clan tracking database models.
Stores tracked clans and daily snapshots of member stats.
"""
from datetime import datetime
from sqlalchemy import Column, String, DateTime, Integer, Float, Boolean, Date
from database import Base


class TrackedClan(Base):
    """Clans that are actively being tracked for statistics."""
    __tablename__ = "tracked_clans"

    clan_tag = Column(String, primary_key=True)
    clan_name = Column(String, nullable=False)
    tracking_started = Column(DateTime, default=datetime.utcnow)
    tracked_by_user_id = Column(Integer, nullable=True)  # User who initiated tracking
    is_active = Column(Boolean, default=True)


class ClanMemberSnapshot(Base):
    """
    Daily snapshots of clan member statistics.
    Used to calculate deltas over time (weekly, monthly stats).
    """
    __tablename__ = "clan_member_snapshots"

    id = Column(Integer, primary_key=True, autoincrement=True)
    clan_tag = Column(String, nullable=False, index=True)
    player_tag = Column(String, nullable=False, index=True)
    player_name = Column(String, nullable=False)

    # Donation stats
    donations_given = Column(Integer, default=0)
    donations_received = Column(Integer, default=0)

    # War stats
    war_attacks = Column(Integer, default=0)
    total_war_attacks = Column(Integer, default=0)
    medals = Column(Integer, default=0)

    # Battle stats
    battles = Column(Integer, default=0)
    wins = Column(Integer, default=0)
    losses = Column(Integer, default=0)

    # Metadata
    snapshot_date = Column(Date, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)
