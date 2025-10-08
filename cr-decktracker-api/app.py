import os, urllib.parse, asyncio
from typing import List, Tuple
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv
import httpx
from rapidfuzz import process, fuzz

# Load API key
load_dotenv()
TOKEN = os.getenv("SUPERCELL_API_TOKEN", "")
if not TOKEN:
    raise RuntimeError("Missing SUPERCELL_API_TOKEN in .env")

BASE = "https://api.clashroyale.com/v1"
HEADERS = {"Authorization": f"Bearer {TOKEN}"}

app = FastAPI(title="Clash Royale Deck Tracker API", version="1.0")

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

# ---- Helper functions ----
def enc_tag(tag: str) -> str:
    """Decode any incoming %23, ensure leading '#', then encode once."""
    tag = urllib.parse.unquote(tag)  # turn %23 back into '#'
    if not tag.startswith("#"):
        tag = "#" + tag
    return urllib.parse.quote(tag, safe="")

async def sc_get(client: httpx.AsyncClient, path: str, params=None):
    """Call Supercell API with error handling"""
    r = await client.get(f"{BASE}{path}", headers=HEADERS, params=params, timeout=10)
    if r.status_code == 429:
        await asyncio.sleep(1)
        r = await client.get(f"{BASE}{path}", headers=HEADERS, params=params, timeout=10)
    if r.is_error:
        raise HTTPException(status_code=r.status_code, detail=r.text)
    return r.json()

def canon(cards: List[dict]) -> Tuple[str, ...]:
    """Normalize deck to sorted tuple of card names"""
    return tuple(sorted(c["name"] for c in cards))

# ---- Endpoints ----
@app.get("/health")
def health():
    return {"ok": True}

@app.post("/resolve_player", response_model=ResolveResp)
async def resolve_player(req: ResolveReq):
    """Find player's tag by fuzzy matching their name inside a clan (by clan tag)."""
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
async def resolve_player_by_name(req: ResolveByNameReq):
    """Find player by searching clan name, then fuzzy matching player within clan."""
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
async def predict(player_tag: str):
    """Fetch recent battles and return top-3 most frequent decks THIS PLAYER used."""
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
            print(f"Battle {i}: found {len(player_cards)} cards in player's deck")
            deck_key = canon(player_cards)
            counts[deck_key] = counts.get(deck_key, 0) + 1
        except Exception as e:
            print(f"Battle {i}: error {e}")

    print(f"Total unique decks found: {len(counts)}")
    
    total = sum(counts.values()) or 1
    top3 = sorted(counts.items(), key=lambda kv: kv[1], reverse=True)[:3]
    decks = [{"deck": list(deck), "confidence": round(n/total, 2)} for deck, n in top3]

    return {"player_tag": player_tag, "top3": decks}

@app.get("/debug/battlelog/{player_tag}")
async def debug_battlelog(player_tag: str):
    """Return raw battle log for debugging"""
    async with httpx.AsyncClient() as client:
        battles = await sc_get(client, f"/players/{enc_tag(player_tag)}/battlelog")
    return {"raw_battles": battles, "count": len(battles)}