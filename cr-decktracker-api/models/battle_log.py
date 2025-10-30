"""
Battle log database model.
Stores cached battle log data for players.
"""
from datetime import datetime
from sqlalchemy import Column, String, DateTime, JSON
from database import Base


class BattleLog(Base):
    """Stores cached battle logs for players with deck analysis."""
    __tablename__ = "battle_logs"

    player_tag = Column(String, primary_key=True)
    battles = Column(JSON)  # Raw battle log data
    fetched_at = Column(DateTime, default=datetime.utcnow)
    deck_analysis = Column(JSON)  # Top 3 decks with confidence scores
