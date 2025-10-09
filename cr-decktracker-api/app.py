import os, urllib.parse, asyncio, hashlib, json
from typing import List, Tuple, Optional
from datetime import datetime, timedelta
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from dotenv import load_dotenv
import httpx
from rapidfuzz import process, fuzz
import redis.asyncio as redis
from sqlalchemy import create_engine, Column, String, DateTime, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from contextlib import asynccontextmanager

# Load environment
load_dotenv()
TOKEN = os.getenv("SUPERCELL_API_TOKEN", "")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://localhost/decktracker")

if not TOKEN:
    raise RuntimeError("Missing SUPERCELL_API_TOKEN in .env")

BASE = "https://api.clashroyale.com/v1"
HEADERS = {"Authorization": f"Bearer {TOKEN}"}

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
    r = await client.get(f"{BASE}{path}", headers=HEADERS, params=params, timeout=10)
    if r.status_code == 429:
        await asyncio.sleep(1)
        r = await client.get(f"{BASE}{path}", headers=HEADERS, params=params, timeout=10)
    if r.is_error:
        raise HTTPException(status_code=r.status_code, detail=r.text)
    
    data = r.json()
    
    # Cache for 5 minutes
    await redis_client.setex(cache_key, 300, json.dumps(data))
    
    return data

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

# ---- Endpoints ----
@app.get("/health")
async def health():
    redis_status = await redis_client.ping()
    return {
        "ok": True,
        "redis": "connected" if redis_status else "disconnected",
        "database": "connected"
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
    