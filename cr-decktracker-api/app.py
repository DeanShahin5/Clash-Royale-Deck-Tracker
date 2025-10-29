import os, urllib.parse, asyncio, hashlib, json
from typing import List, Tuple, Optional
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException, Request, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from dotenv import load_dotenv
import httpx
from rapidfuzz import process, fuzz
import redis.asyncio as redis
from sqlalchemy import create_engine, Column, String, DateTime, JSON, Integer, Float, Boolean, Date
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from contextlib import asynccontextmanager
import bcrypt
import jwt
from collections import defaultdict

# Load environment
load_dotenv()
TOKEN = os.getenv("SUPERCELL_API_TOKEN", "")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://localhost/decktracker")
JWT_SECRET = os.getenv("JWT_SECRET", "your-secret-key-change-in-production")
JWT_ALGORITHM = "HS256"

if not TOKEN:
    raise RuntimeError("Missing SUPERCELL_API_TOKEN in .env")

BASE = "https://api.clashroyale.com/v1"
HEADERS = {"Authorization": f"Bearer {TOKEN}"}

# Security
security = HTTPBearer()

# Database setup
Base = declarative_base()
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)

class BattleLog(Base):
    __tablename__ = "battle_logs"

    player_tag = Column(String, primary_key=True)
    battles = Column(JSON)
    fetched_at = Column(DateTime, default=datetime.utcnow)
    deck_analysis = Column(JSON)

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    player_tag = Column(String, nullable=True)
    clan_tag = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class TrackedClan(Base):
    __tablename__ = "tracked_clans"

    clan_tag = Column(String, primary_key=True)
    clan_name = Column(String, nullable=False)
    tracking_started = Column(DateTime, default=datetime.utcnow)
    tracked_by_user_id = Column(Integer, nullable=True)
    is_active = Column(Boolean, default=True)

class ClanMemberSnapshot(Base):
    __tablename__ = "clan_member_snapshots"

    id = Column(Integer, primary_key=True, autoincrement=True)
    clan_tag = Column(String, nullable=False, index=True)
    player_tag = Column(String, nullable=False, index=True)
    player_name = Column(String, nullable=False)
    donations_given = Column(Integer, default=0)
    donations_received = Column(Integer, default=0)
    war_attacks = Column(Integer, default=0)
    total_war_attacks = Column(Integer, default=0)
    medals = Column(Integer, default=0)
    battles = Column(Integer, default=0)
    wins = Column(Integer, default=0)
    losses = Column(Integer, default=0)
    snapshot_date = Column(Date, nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)

# Create tables
Base.metadata.create_all(engine)

# Redis client
redis_client: Optional[redis.Redis] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    global redis_client
    redis_client = await redis.from_url(REDIS_URL, decode_responses=True)
    print("✅ Connected to Redis")
    yield
    # Shutdown
    await redis_client.close()
    print("❌ Disconnected from Redis")

app = FastAPI(
    title="Clash Royale Deck Tracker API",
    version="2.0",
    lifespan=lifespan
)

# ---- Models ----
class ResolveReq(BaseModel):
    player_name: str
    clan_tag: str

class ResolveByNameReq(BaseModel):
    player_name: str
    clan_name: str

class ResolveResp(BaseModel):
    player_tag: str
    name: str
    confidence: int

class Deck(BaseModel):
    deck: List[str]
    confidence: float

class PredictResp(BaseModel):
    player_tag: str
    top3: List[Deck]
    cached: bool = False

class RegisterReq(BaseModel):
    email: EmailStr
    password: str
    player_tag: Optional[str] = None
    clan_tag: Optional[str] = None

class LoginReq(BaseModel):
    email: EmailStr
    password: str

class AuthResp(BaseModel):
    token: str
    email: str
    player_tag: Optional[str] = None
    clan_tag: Optional[str] = None

class MemberStats(BaseModel):
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
    clan_name: str
    clan_tag: str
    members: List[MemberStats]
    time_period: str
    is_tracked: bool = False
    tracking_since: Optional[str] = None

class TrackClanResp(BaseModel):
    message: str
    clan_tag: str
    clan_name: str
    tracking_started: str
    snapshot_created: bool

class BattleInfo(BaseModel):
    type: str
    battle_time: str
    result: Optional[str] = None
    crowns: int
    opponent_crowns: int
    deck: List[str]
    arena: Optional[str] = None
    player_trophies: Optional[int] = None
    opponent_name: Optional[str] = None
    opponent_trophies: Optional[int] = None

class PlayerStatsResp(BaseModel):
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

# ---- Authentication Helpers ----
def hash_password(password: str) -> str:
    """Hash a password using bcrypt"""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    """Verify a password against its hash"""
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

def create_jwt_token(email: str, player_tag: Optional[str] = None) -> str:
    """Create JWT token"""
    payload = {
        "email": email,
        "player_tag": player_tag,
        "exp": datetime.utcnow() + timedelta(days=30)
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def decode_jwt_token(token: str) -> dict:
    """Decode and verify JWT token"""
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid token")

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Dependency to get current authenticated user"""
    token = credentials.credentials
    return decode_jwt_token(token)

def get_db():
    """Database dependency"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ---- Rate Limiting ----
async def check_rate_limit(identifier: str) -> bool:
    """Check if request is within rate limit (100 requests per hour per IP)"""
    key = f"ratelimit:{identifier}"
    count = await redis_client.get(key)

    if count is None:
        await redis_client.setex(key, 3600, 1)  # 1 hour expiry
        return True
    elif int(count) < 100:
        await redis_client.incr(key)
        return True
    else:
        return False

# ---- Helper functions ----
def enc_tag(tag: str) -> str:
    """Decode any incoming %23, ensure leading '#', then encode once."""
    tag = urllib.parse.unquote(tag)
    if not tag.startswith("#"):
        tag = "#" + tag
    return urllib.parse.quote(tag, safe="")

async def sc_get(client: httpx.AsyncClient, path: str, params=None):
    """Call Supercell API with Redis caching"""
    # Create cache key
    cache_key = f"api:{path}:{hashlib.md5(str(params).encode()).hexdigest()}"

    # Check Redis cache first
    cached = await redis_client.get(cache_key)
    if cached:
        print(f"✅ Cache HIT: {path}")
        return json.loads(cached)

    print(f"❌ Cache MISS: {path}")

    # Make API call
    try:
        r = await client.get(f"{BASE}{path}", headers=HEADERS, params=params, timeout=10)

        if r.status_code == 429:
            print(f"⚠️ Rate limited on {path}, retrying...")
            await asyncio.sleep(1)
            r = await client.get(f"{BASE}{path}", headers=HEADERS, params=params, timeout=10)

        if r.status_code == 404:
            error_detail = r.json() if r.text else {}
            reason = error_detail.get("reason", "notFound")
            print(f"❌ 404 Not Found: {path} - {reason}")

            # Provide more helpful error messages
            if "clan" in path.lower():
                raise HTTPException(
                    status_code=404,
                    detail="Clan not found. Please check that your clan tag is correct (e.g., #ABC123)."
                )
            elif "player" in path.lower():
                raise HTTPException(
                    status_code=404,
                    detail="Player not found. Please check that the player tag is correct."
                )
            else:
                raise HTTPException(
                    status_code=404,
                    detail=f"Resource not found. Please verify the information is correct."
                )

        if r.status_code == 403:
            print(f"❌ 403 Forbidden: {path} - Invalid API token or access denied")
            raise HTTPException(
                status_code=403,
                detail="API access denied. Please check your API token."
            )

        if r.is_error:
            print(f"❌ Error {r.status_code}: {path} - {r.text}")
            raise HTTPException(status_code=r.status_code, detail=r.text)

        data = r.json()

        # Cache for 5 minutes
        await redis_client.setex(cache_key, 300, json.dumps(data))

        return data

    except httpx.TimeoutException:
        print(f"❌ Timeout on {path}")
        raise HTTPException(status_code=504, detail="Request to Supercell API timed out")
    except httpx.RequestError as e:
        print(f"❌ Request error on {path}: {e}")
        raise HTTPException(status_code=503, detail=f"Failed to connect to Supercell API: {str(e)}")

def canon(cards: List[dict]) -> Tuple[str, ...]:
    """Normalize deck to sorted tuple of card names"""
    return tuple(sorted(c["name"] for c in cards))

def save_battle_log(player_tag: str, battles: list, deck_analysis: dict):
    """Save battle log to Postgres"""
    db = SessionLocal()
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

def get_cached_battle_log(player_tag: str) -> Optional[dict]:
    """Get battle log from Postgres if recent (within 10 minutes)"""
    db = SessionLocal()
    try:
        log = db.query(BattleLog).filter_by(player_tag=player_tag).first()
        if log and (datetime.utcnow() - log.fetched_at) < timedelta(minutes=10):
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

def calculate_wins_losses(battles: list, player_tag: str) -> Tuple[int, int]:
    """Calculate wins and losses from battle log"""
    wins = 0
    losses = 0

    for battle in battles:
        # Skip battles without team data
        if "team" not in battle or not battle["team"]:
            continue

        # Skip non-PvP battles (skip 2v2, etc.)
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
    """Calculate stats for a specific battle mode (ranked/ladder)"""
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

async def create_clan_snapshot(clan_tag: str, db: Session) -> bool:
    """Create a snapshot of all clan member stats for today"""
    try:
        today = datetime.utcnow().date()

        # Check if snapshot already exists for today
        existing = db.query(ClanMemberSnapshot).filter_by(
            clan_tag=clan_tag,
            snapshot_date=today
        ).first()

        if existing:
            print(f"Snapshot already exists for {clan_tag} on {today}")
            return False

        async with httpx.AsyncClient() as client:
            # Fetch clan members
            members_data = await sc_get(client, f"/clans/{enc_tag(clan_tag)}/members")
            members = members_data.get("items", [])

            # Fetch river race data for medals/war attacks
            try:
                river_race_data = await sc_get(client, f"/clans/{enc_tag(clan_tag)}/riverracelog")
                river_race = river_race_data.get("items", [])
            except:
                river_race = []

            # Create snapshot for each member
            for member in members:
                member_tag = member["tag"]

                # Calculate war stats from river race
                medals = 0
                war_attacks = 0
                total_war_attacks = 0

                for race in river_race[:5]:  # Last 5 races
                    if "standings" in race:
                        for standing in race["standings"]:
                            if standing.get("clan", {}).get("tag") == clan_tag:
                                participants = standing.get("clan", {}).get("participants", [])
                                for p in participants:
                                    if p.get("tag") == member_tag:
                                        medals += p.get("fame", 0)
                                        war_attacks += p.get("decksUsed", 0)
                                        total_war_attacks += 4

                # Fetch battle count and calculate wins/losses
                try:
                    battle_log = await sc_get(client, f"/players/{enc_tag(member_tag)}/battlelog")
                    battles = battle_log if isinstance(battle_log, list) else battle_log.get("items", [])
                    battle_count = len(battles)
                    wins, losses = calculate_wins_losses(battles, member_tag)
                except:
                    battle_count = 0
                    wins = 0
                    losses = 0

                # Create snapshot
                snapshot = ClanMemberSnapshot(
                    clan_tag=clan_tag,
                    player_tag=member_tag,
                    player_name=member["name"],
                    donations_given=member.get("donations", 0),
                    donations_received=member.get("donationsReceived", 0),
                    war_attacks=war_attacks,
                    total_war_attacks=total_war_attacks,
                    medals=medals,
                    battles=battle_count,
                    wins=wins,
                    losses=losses,
                    snapshot_date=today
                )
                db.add(snapshot)

            db.commit()
            print(f"✅ Created snapshot for {len(members)} members in clan {clan_tag}")
            return True

    except Exception as e:
        print(f"Error creating snapshot for {clan_tag}: {e}")
        db.rollback()
        return False

def get_historical_stats(clan_tag: str, time_period: str, db: Session) -> List[dict]:
    """Get historical stats from snapshots with deltas"""
    today = datetime.utcnow().date()

    # Calculate date range
    days_ago = {
        "week": 7,
        "2weeks": 14,
        "month": 30,
        "all": 9999
    }.get(time_period, 7)

    start_date = today - timedelta(days=days_ago)

    # Get latest snapshot for each member
    latest_snapshots = db.query(ClanMemberSnapshot).filter(
        ClanMemberSnapshot.clan_tag == clan_tag,
        ClanMemberSnapshot.snapshot_date == today
    ).all()

    if not latest_snapshots:
        return None

    # Get snapshots from start_date
    old_snapshots = db.query(ClanMemberSnapshot).filter(
        ClanMemberSnapshot.clan_tag == clan_tag,
        ClanMemberSnapshot.snapshot_date >= start_date,
        ClanMemberSnapshot.snapshot_date < today
    ).all()

    # Create lookup for old snapshots
    old_lookup = {}
    for snap in old_snapshots:
        if snap.player_tag not in old_lookup:
            old_lookup[snap.player_tag] = snap

    # Calculate deltas
    results = []
    for latest in latest_snapshots:
        old = old_lookup.get(latest.player_tag)

        if old:
            # Calculate deltas
            donations_delta = latest.donations_given - old.donations_given
            donations_received_delta = latest.donations_received - old.donations_received
            war_attacks_delta = latest.war_attacks - old.war_attacks
            medals_delta = latest.medals - old.medals
            battles_delta = latest.battles - old.battles
            wins_delta = latest.wins - old.wins
            losses_delta = latest.losses - old.losses
        else:
            # No historical data, use current values
            donations_delta = latest.donations_given
            donations_received_delta = latest.donations_received
            war_attacks_delta = latest.war_attacks
            medals_delta = latest.medals
            battles_delta = latest.battles
            wins_delta = latest.wins
            losses_delta = latest.losses

        results.append({
            "name": latest.player_name,
            "tag": latest.player_tag,
            "donations": donations_delta,
            "donations_received": donations_received_delta,
            "war_attacks": war_attacks_delta,
            "total_war_attacks": latest.total_war_attacks,
            "medals": medals_delta,
            "battles": battles_delta,
            "wins": wins_delta,
            "losses": losses_delta,
            "last_seen": None
        })

    return results

# ---- Endpoints ----
@app.get("/health")
async def health():
    redis_status = await redis_client.ping()
    return {
        "ok": True,
        "redis": "connected" if redis_status else "disconnected",
        "database": "connected"
    }

# ---- Authentication Endpoints ----
@app.post("/auth/register", response_model=AuthResp)
async def register(req: RegisterReq, db: Session = Depends(get_db)):
    """Register a new user"""
    # Check if email already exists
    existing_user = db.query(User).filter_by(email=req.email).first()
    if existing_user:
        raise HTTPException(400, "Email already registered")

    # Create new user
    user = User(
        email=req.email,
        password_hash=hash_password(req.password),
        player_tag=req.player_tag,
        clan_tag=req.clan_tag
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # Generate token
    token = create_jwt_token(user.email, user.player_tag)

    return {
        "token": token,
        "email": user.email,
        "player_tag": user.player_tag,
        "clan_tag": user.clan_tag
    }

@app.post("/auth/login", response_model=AuthResp)
async def login(req: LoginReq, db: Session = Depends(get_db)):
    """Login user"""
    # Find user
    user = db.query(User).filter_by(email=req.email).first()
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(401, "Invalid email or password")

    # Generate token
    token = create_jwt_token(user.email, user.player_tag)

    return {
        "token": token,
        "email": user.email,
        "player_tag": user.player_tag,
        "clan_tag": user.clan_tag
    }

@app.get("/auth/me")
async def get_me(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    """Get current user info"""
    user = db.query(User).filter_by(email=current_user["email"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    return {
        "email": user.email,
        "player_tag": user.player_tag,
        "clan_tag": user.clan_tag
    }

# ---- Clan Tracking Endpoints ----
@app.post("/clan/{clan_tag}/track", response_model=TrackClanResp)
async def start_tracking_clan(
    clan_tag: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Start tracking a clan's stats (requires authentication)"""

    # Check if clan is already tracked
    tracked = db.query(TrackedClan).filter_by(clan_tag=clan_tag).first()

    if tracked:
        return {
            "message": "Clan is already being tracked",
            "clan_tag": tracked.clan_tag,
            "clan_name": tracked.clan_name,
            "tracking_started": tracked.tracking_started.isoformat(),
            "snapshot_created": False
        }

    # Fetch clan info to get name
    async with httpx.AsyncClient() as client:
        clan_data = await sc_get(client, f"/clans/{enc_tag(clan_tag)}")

    clan_name = clan_data.get("name", "Unknown")

    # Get user ID
    user = db.query(User).filter_by(email=current_user["email"]).first()
    user_id = user.id if user else None

    # Create tracked clan entry
    tracked_clan = TrackedClan(
        clan_tag=clan_tag,
        clan_name=clan_name,
        tracked_by_user_id=user_id,
        is_active=True
    )
    db.add(tracked_clan)
    db.commit()
    db.refresh(tracked_clan)

    # Create initial snapshot
    snapshot_created = await create_clan_snapshot(clan_tag, db)

    return {
        "message": "Clan tracking started successfully",
        "clan_tag": clan_tag,
        "clan_name": clan_name,
        "tracking_started": tracked_clan.tracking_started.isoformat(),
        "snapshot_created": snapshot_created
    }

@app.get("/clan/{clan_tag}/tracking-status")
async def get_tracking_status(clan_tag: str, db: Session = Depends(get_db)):
    """Check if a clan is being tracked"""
    tracked = db.query(TrackedClan).filter_by(clan_tag=clan_tag, is_active=True).first()

    if not tracked:
        return {
            "is_tracked": False,
            "tracking_since": None,
            "clan_name": None
        }

    return {
        "is_tracked": True,
        "tracking_since": tracked.tracking_started.isoformat(),
        "clan_name": tracked.clan_name
    }

@app.post("/clan/{clan_tag}/snapshot")
async def create_snapshot(
    clan_tag: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Manually create a snapshot for a tracked clan"""

    # Check if clan is tracked
    tracked = db.query(TrackedClan).filter_by(clan_tag=clan_tag, is_active=True).first()
    if not tracked:
        raise HTTPException(404, "Clan is not being tracked")

    # Create snapshot
    created = await create_clan_snapshot(clan_tag, db)

    return {
        "message": "Snapshot created" if created else "Snapshot already exists for today",
        "created": created,
        "clan_tag": clan_tag,
        "date": datetime.utcnow().date().isoformat()
    }

@app.post("/resolve_player", response_model=ResolveResp)
async def resolve_player(req: ResolveReq, request: Request):
    """Find player's tag by fuzzy matching their name inside a clan (by clan tag)."""
    
    # Rate limiting
    client_ip = request.client.host
    if not await check_rate_limit(client_ip):
        raise HTTPException(status_code=429, detail="Rate limit exceeded. Try again in an hour.")
    
    async with httpx.AsyncClient() as client:
        data = await sc_get(client, f"/clans/{enc_tag(req.clan_tag)}/members")
    
    members = data.get("items", [])
    if not members:
        raise HTTPException(404, "No members found for that clan tag")

    names = [m["name"] for m in members]
    match = process.extractOne(req.player_name, names, scorer=fuzz.WRatio)
    
    if not match or match[1] < 70:
        raise HTTPException(404, f"No close match found. Best was: {match}")

    chosen = next(m for m in members if m["name"] == match[0])
    return {
        "player_tag": chosen["tag"],
        "name": chosen["name"],
        "confidence": int(match[1])
    }

@app.post("/resolve_player_by_name", response_model=ResolveResp)
async def resolve_player_by_name(req: ResolveByNameReq, request: Request):
    """Find player by searching clan name, then fuzzy matching player within clan."""
    
    # Rate limiting
    client_ip = request.client.host
    if not await check_rate_limit(client_ip):
        raise HTTPException(status_code=429, detail="Rate limit exceeded. Try again in an hour.")
    
    async with httpx.AsyncClient() as client:
        clan_search = await sc_get(client, "/clans", params={"name": req.clan_name, "limit": 10})
    
    clans = clan_search.get("items", [])
    if not clans:
        raise HTTPException(404, f"No clans found matching '{req.clan_name}'")
    
    print(f"Found {len(clans)} clans matching '{req.clan_name}'")
    
    async with httpx.AsyncClient() as client:
        for clan in clans:
            try:
                members_data = await sc_get(client, f"/clans/{enc_tag(clan['tag'])}/members")
                members = members_data.get("items", [])
                names = [m["name"] for m in members]
                
                match = process.extractOne(req.player_name, names, scorer=fuzz.WRatio)
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
    
    raise HTTPException(404, f"Player '{req.player_name}' not found in any clan named '{req.clan_name}'")

@app.get("/predict/{player_tag}", response_model=PredictResp)
async def predict(player_tag: str, request: Request):
    """Fetch recent battles and return top-3 most frequent decks THIS PLAYER used."""
    
    # Rate limiting
    client_ip = request.client.host
    if not await check_rate_limit(client_ip):
        raise HTTPException(status_code=429, detail="Rate limit exceeded. Try again in an hour.")
    
    # Check Postgres cache first
    cached_data = get_cached_battle_log(player_tag)
    if cached_data:
        return {
            "player_tag": player_tag,
            "top3": cached_data["deck_analysis"]["top3"],
            "cached": True
        }
    
    async with httpx.AsyncClient() as client:
        response = await sc_get(client, f"/players/{enc_tag(player_tag)}/battlelog")
    
    battles = response if isinstance(response, list) else response.get("items", [])
    
    print(f"Fetched {len(battles)} battles for {player_tag}")
    
    # Filter for ranked/ladder matches only
    ranked_battles = [b for b in battles if b.get("type") in ["pathOfLegend", "ladder"]]
    print(f"Found {len(ranked_battles)} ranked battles out of {len(battles)} total")
    
    counts: dict[Tuple[str,...], int] = {}
    for i, b in enumerate(ranked_battles):
        try:
            if "team" not in b or not b["team"]:
                continue
                
            player_cards = b["team"][0]["cards"]
            deck_key = canon(player_cards)
            counts[deck_key] = counts.get(deck_key, 0) + 1
        except Exception as e:
            print(f"Battle {i}: error {e}")

    print(f"Total unique decks found: {len(counts)}")
    
    total = sum(counts.values()) or 1
    top3 = sorted(counts.items(), key=lambda kv: kv[1], reverse=True)[:3]
    decks = [{"deck": list(deck), "confidence": round(n/total, 2)} for deck, n in top3]
    
    # Save to database
    deck_analysis = {"top3": decks}
    save_battle_log(player_tag, ranked_battles, deck_analysis)

    return {
        "player_tag": player_tag,
        "top3": decks,
        "cached": False
    }

@app.get("/clan/{clan_tag}/stats", response_model=ClanStatsResp)
async def get_clan_stats(
    clan_tag: str,
    time_period: str = "week",
    request: Request = None
):
    """Get clan member statistics with time period filter - LIVE DATA ONLY

    time_period options: 'week', '2weeks', 'month', 'all'
    Always uses live Supercell API data (no database required)
    """
    try:
        # Rate limiting
        if request:
            client_ip = request.client.host
            if not await check_rate_limit(client_ip):
                raise HTTPException(status_code=429, detail="Rate limit exceeded. Try again in an hour.")

        # Create cache key
        cache_key = f"clan_stats:{clan_tag}:{time_period}"

        # Check Redis cache
        cached = await redis_client.get(cache_key)
        if cached:
            print(f"✅ Clan stats cache HIT: {clan_tag} - {time_period}")
            return json.loads(cached)

        print(f"❌ Clan stats cache MISS: {clan_tag} - {time_period}")

        async with httpx.AsyncClient() as client:
            # Fetch clan info
            clan_data = await sc_get(client, f"/clans/{enc_tag(clan_tag)}")
            clan_name = clan_data.get("name", "Unknown")

            # Fetch clan members
            members_data = await sc_get(client, f"/clans/{enc_tag(clan_tag)}/members")
            members = members_data.get("items", [])

            # Fetch war log (for war participation)
            try:
                war_log_data = await sc_get(client, f"/clans/{enc_tag(clan_tag)}/warlog")
                war_log = war_log_data.get("items", [])
            except:
                war_log = []

            # Fetch river race log (for medals and attacks)
            try:
                river_race_data = await sc_get(client, f"/clans/{enc_tag(clan_tag)}/riverracelog")
                river_race = river_race_data.get("items", [])
            except:
                river_race = []

            # Process each member
            member_stats_list = []
            for member in members:
                member_tag = member["tag"]

                try:
                    # Fetch player details
                    player_data = await sc_get(client, f"/players/{enc_tag(member_tag)}")

                    # Fetch battle log for battles count
                    battle_log = await sc_get(client, f"/players/{enc_tag(member_tag)}/battlelog")
                    battles = battle_log if isinstance(battle_log, list) else battle_log.get("items", [])

                    # Calculate time filter (days)
                    days_filter = {
                        "week": 7,
                        "2weeks": 14,
                        "month": 30,
                        "all": 9999
                    }.get(time_period, 7)

                    cutoff_date = datetime.utcnow() - timedelta(days=days_filter)

                    # Filter battles by time period
                    filtered_battles = []
                    for battle in battles:
                        if "battleTime" in battle:
                            battle_time = datetime.strptime(battle["battleTime"], "%Y%m%dT%H%M%S.%fZ")
                            if battle_time >= cutoff_date:
                                filtered_battles.append(battle)

                    # Calculate wins and losses
                    wins, losses = calculate_wins_losses(filtered_battles, member_tag)

                    # Calculate ranked (Path of Legend) stats
                    ranked_stats = calculate_mode_stats(filtered_battles, "pathOfLegend")

                    # Calculate ladder stats (Trophy Road uses "trail" type)
                    ladder_stats = calculate_mode_stats(filtered_battles, "trail")

                    # Count war attacks in river race
                    war_attacks = 0
                    total_war_attacks = 0

                    for race in river_race[:5]:  # Last 5 races
                        if "standings" in race:
                            for standing in race["standings"]:
                                if standing.get("clan", {}).get("tag") == clan_tag:
                                    participants = standing.get("clan", {}).get("participants", [])
                                    for p in participants:
                                        if p.get("tag") == member_tag:
                                            war_attacks += p.get("decksUsed", 0)
                                            total_war_attacks += 4  # Max 4 attacks per race

                    member_stats_list.append({
                        "name": member["name"],
                        "tag": member_tag,
                        "donations": member.get("donations", 0),
                        "donations_received": member.get("donationsReceived", 0),
                        "war_attacks": war_attacks,
                        "total_war_attacks": total_war_attacks,
                        "battles": len(filtered_battles),
                        "wins": wins,
                        "losses": losses,
                        "ranked_battles": ranked_stats["battles"],
                        "ranked_wins": ranked_stats["wins"],
                        "ranked_losses": ranked_stats["losses"],
                        "ranked_avg_crowns": ranked_stats["avg_crowns"],
                        "ladder_battles": ladder_stats["battles"],
                        "ladder_wins": ladder_stats["wins"],
                        "ladder_losses": ladder_stats["losses"],
                        "ladder_avg_crowns": ladder_stats["avg_crowns"],
                        "last_seen": player_data.get("lastSeen", None)
                    })
                except Exception as e:
                    print(f"Error fetching stats for {member_tag}: {e}")
                    # Add with zero stats if error
                    member_stats_list.append({
                        "name": member["name"],
                        "tag": member_tag,
                        "donations": member.get("donations", 0),
                        "donations_received": member.get("donationsReceived", 0),
                        "war_attacks": 0,
                        "total_war_attacks": 0,
                        "battles": 0,
                        "wins": 0,
                        "losses": 0,
                        "ranked_battles": 0,
                        "ranked_wins": 0,
                        "ranked_losses": 0,
                        "ranked_avg_crowns": 0.0,
                        "ladder_battles": 0,
                        "ladder_wins": 0,
                        "ladder_losses": 0,
                        "ladder_avg_crowns": 0.0,
                        "last_seen": None
                    })

        response_data = {
            "clan_name": clan_name,
            "clan_tag": clan_tag,
            "members": member_stats_list,
            "time_period": time_period,
            "is_tracked": False,
            "tracking_since": None
        }

        # Cache for 5 minutes
        await redis_client.setex(cache_key, 300, json.dumps(response_data))

        return response_data

    except HTTPException:
        # Re-raise HTTPExceptions (from sc_get) as-is
        raise
    except Exception as e:
        print(f"❌ Unexpected error in get_clan_stats: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"An error occurred while fetching clan stats. Please try again later."
        )

@app.get("/player/{player_tag}/stats", response_model=PlayerStatsResp)
async def get_player_stats(player_tag: str, request: Request = None):
    """Get detailed player statistics including recent battles and top decks"""
    try:
        # Rate limiting
        if request:
            client_ip = request.client.host
            if not await check_rate_limit(client_ip):
                raise HTTPException(status_code=429, detail="Rate limit exceeded. Try again in an hour.")

        async with httpx.AsyncClient() as client:
            # Fetch player data
            player_data = await sc_get(client, f"/players/{enc_tag(player_tag)}")

            # Fetch battle log
            battle_log = await sc_get(client, f"/players/{enc_tag(player_tag)}/battlelog")
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

                    # Get additional battle details
                    arena_name = battle.get("arena", {}).get("name")
                    player_trophies = team.get("startingTrophies")
                    opponent_name = opponent.get("name")
                    opponent_trophies = opponent.get("startingTrophies")

                    recent_battles.append({
                        "type": battle.get("type", "unknown"),
                        "battle_time": battle.get("battleTime", ""),
                        "result": result,
                        "crowns": team_crowns,
                        "opponent_crowns": opponent_crowns,
                        "deck": deck_cards,
                        "arena": arena_name,
                        "player_trophies": player_trophies,
                        "opponent_name": opponent_name,
                        "opponent_trophies": opponent_trophies
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

    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error in get_player_stats: {e}")
        raise HTTPException(
            status_code=500,
            detail="An error occurred while fetching player stats. Please try again later."
        )

@app.get("/stats")
async def stats():
    """Get cache and database statistics"""
    db = SessionLocal()
    try:
        battle_count = db.query(BattleLog).count()

        # Redis info
        redis_info = await redis_client.info("stats")

        return {
            "database": {
                "battle_logs_cached": battle_count
            },
            "redis": {
                "keyspace_hits": redis_info.get("keyspace_hits", 0),
                "keyspace_misses": redis_info.get("keyspace_misses", 0)
            }
        }
    finally:
        db.close()

@app.delete("/cache/clear")
async def clear_cache():
    """Clear all Redis cache (admin endpoint)"""
    await redis_client.flushdb()
    return {"message": "Redis cache cleared successfully"}

@app.get("/debug/battlelog/{player_tag}")
async def debug_battlelog(player_tag: str):
    """Return raw battle log for debugging"""
    async with httpx.AsyncClient() as client:
        battles = await sc_get(client, f"/players/{enc_tag(player_tag)}/battlelog")
    return {"raw_battles": battles, "count": len(battles)}