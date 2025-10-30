"""
User database model for authentication and profile management.
"""
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime
from database import Base


class User(Base):
    """User accounts with authentication and profile information."""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    player_tag = Column(String, nullable=True)  # Linked Clash Royale player
    clan_tag = Column(String, nullable=True)  # Linked Clash Royale clan
    created_at = Column(DateTime, default=datetime.utcnow)
