"""
Database connection and session management.
Provides SQLAlchemy engine, session factory, and base model class.
"""
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from config import DATABASE_URL

# Create SQLAlchemy engine
engine = create_engine(DATABASE_URL)

# Create session factory
SessionLocal = sessionmaker(bind=engine)

# Base class for all database models
Base = declarative_base()

def init_db():
    """Initialize database by creating all tables."""
    from models import battle_log, user, clan  # Import all models
    Base.metadata.create_all(engine)
    print("✅ Database tables created successfully")

def get_db():
    """
    FastAPI dependency to get database session.
    Ensures session is properly closed after use.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
