# API Architecture Documentation

## Overview

The backend has been refactored from a monolithic 1555-line `app.py` into a clean, modular architecture. This makes the codebase easier to navigate, maintain, and extend.

## Directory Structure

```
cr-decktracker-api/
├── app.py                  # Main FastAPI application (108 lines)
├── config.py              # Environment variables and configuration
├── database.py            # Database connection and session management
├── dependencies.py        # FastAPI dependencies (auth, database)
│
├── models/                # SQLAlchemy database models
│   ├── __init__.py
│   ├── battle_log.py      # Battle log cache model
│   ├── user.py            # User accounts model
│   └── clan.py            # Clan tracking models
│
├── schemas/               # Pydantic request/response models
│   ├── __init__.py
│   ├── auth.py            # Auth-related schemas
│   ├── player.py          # Player-related schemas
│   └── clan.py            # Clan-related schemas
│
├── middleware/            # Custom middleware
│   ├── __init__.py
│   └── security.py        # CORS and security headers
│
├── utils/                 # Utility functions
│   ├── __init__.py
│   ├── validation.py      # Input validation (tags, passwords)
│   ├── rate_limiting.py   # Redis-based rate limiting
│   ├── helpers.py         # General helpers (battle stats, caching)
│   └── auth.py            # Password hashing and JWT tokens
│
├── services/              # Business logic layer
│   ├── __init__.py
│   ├── supercell_api.py   # Supercell API client with caching
│   ├── clan_service.py    # Clan tracking and snapshots
│   └── player_service.py  # Player resolution and statistics
│
└── routes/                # API route handlers
    ├── __init__.py
    ├── health.py          # Health checks and system stats
    ├── auth.py            # Authentication endpoints
    ├── player.py          # Player endpoints
    └── clan.py            # Clan endpoints
```

## Architecture Layers

### 1. **Configuration Layer** (`config.py`)
- Centralizes all environment variables
- Defines API tokens, database URLs, cache settings
- Security constants (password requirements, rate limits)

### 2. **Database Layer** (`database.py`, `models/`)
- **database.py**: SQLAlchemy engine and session factory
- **models/**: Database table definitions
  - `battle_log.py`: Cached battle logs with deck analysis
  - `user.py`: User accounts with authentication
  - `clan.py`: Tracked clans and member snapshots

### 3. **Schema Layer** (`schemas/`)
- Pydantic models for request validation and response serialization
- Organized by domain (auth, player, clan)
- Provides automatic API documentation

### 4. **Middleware Layer** (`middleware/`)
- **security.py**: CORS configuration and security headers
  - Content Security Policy
  - XSS protection
  - Clickjacking prevention
  - HTTPS enforcement (production)

### 5. **Utilities Layer** (`utils/`)
- **validation.py**: Input sanitization and validation
  - Player/clan tag format validation
  - Password strength enforcement
  - String sanitization

- **rate_limiting.py**: Redis-based rate limiting
  - General: 100 req/hour per IP
  - Auth: 5 req/minute per IP

- **auth.py**: Authentication utilities
  - bcrypt password hashing
  - JWT token creation/validation

- **helpers.py**: Common operations
  - Battle win/loss calculation
  - Deck normalization
  - Database caching helpers

### 6. **Service Layer** (`services/`)
Business logic abstracted from route handlers:

- **supercell_api.py**: Supercell API client
  - Request caching with Redis
  - Automatic retry on rate limits
  - Detailed error handling

- **clan_service.py**: Clan operations
  - Snapshot creation
  - Historical statistics
  - Delta calculations

- **player_service.py**: Player operations
  - Player resolution (fuzzy matching)
  - Deck prediction
  - Statistics aggregation

### 7. **Routes Layer** (`routes/`)
Clean, focused route handlers:

- **health.py**: System health and statistics
- **auth.py**: User registration, login, profile
- **player.py**: Player resolution, deck prediction, stats
- **clan.py**: Clan tracking, snapshots, statistics

## Key Design Principles

### Separation of Concerns
- **Routes**: Handle HTTP requests/responses only
- **Services**: Contain business logic
- **Utils**: Provide reusable functions
- **Models**: Define data structure

### Dependency Injection
- Database sessions via FastAPI `Depends()`
- Redis client injected into routes
- Easy to mock for testing

### Security Best Practices
- Input validation at multiple levels
- Rate limiting on all endpoints
- Secure password hashing (bcrypt)
- JWT tokens with expiration
- Security headers on all responses

### Caching Strategy
- **Redis**: Short-term API response cache (5 minutes)
- **PostgreSQL**: Long-term battle log cache (10 minutes)
- **Snapshots**: Daily clan member statistics

## Migration from Old Code

The original `app.py` (1555 lines) has been:
- Backed up to `app.py.backup`
- Replaced with a clean 108-line main file
- All code preserved and organized into modules

### Benefits
✅ **Maintainability**: Each file has a single responsibility
✅ **Readability**: Clear organization, easy to find code
✅ **Testability**: Isolated functions are easier to test
✅ **Scalability**: Easy to add new features without clutter
✅ **Onboarding**: New developers can understand structure quickly

## Running the Application

```bash
# Install dependencies
pip install -r requirements.txt

# Run the server
uvicorn app:app --reload

# Or use the built-in runner
python app.py
```

## Adding New Features

### Adding a New Endpoint
1. Create route handler in appropriate file in `routes/`
2. Add business logic in `services/` if needed
3. Define schemas in `schemas/` for request/response
4. Add utility functions in `utils/` if needed

### Adding a New Model
1. Create model in `models/`
2. Import in `models/__init__.py`
3. Run database migration or restart to create tables

### Adding a New Service
1. Create service file in `services/`
2. Implement business logic using services and utilities
3. Import and use in route handlers

## Code Style

- **Docstrings**: All functions have clear documentation
- **Comments**: Added where business logic isn't obvious
- **Type hints**: Used throughout for clarity
- **Async/await**: Properly used for I/O operations
- **Error handling**: Comprehensive with helpful messages

## Security Notes

- Environment variables required in `.env`
- JWT secret should be changed in production
- CORS origins should be restricted in production
- Rate limiting prevents abuse
- Password requirements enforce strong security
