#!/usr/bin/env python3
"""Astro Royale V35 account/cloud + OAuth + authoritative 10-player realtime backend.

HTTP handles account/profile/cloud persistence. A WebSocket server provides
a real authenticated matchmaking queue and room for up to 10 concurrent
players, team assignment, movement/actions, authoritative state broadcasts,
core/tower/objective damage, disconnect handling and server-side settlement.
The default queue requires 10 real authenticated clients; development can set
MATCHMAKING_MIN_PLAYERS lower for a controlled test.
"""
import hashlib
import hmac
import json
import os
import secrets
import sqlite3
import time
import asyncio
import threading
from collections import defaultdict

try:
    from websockets.asyncio.server import serve
except Exception:
    serve = None
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlparse, urlunparse
from urllib.request import Request as URLRequest, urlopen

HOST = os.getenv("ASTRO_HOST", "127.0.0.1")
PORT = int(os.getenv("ASTRO_PORT", "8787"))
WS_PORT = int(os.getenv("ASTRO_WS_PORT", "8788"))
DB = Path(os.getenv("ASTRO_DB", "astro_royale_v36.sqlite3"))
MIN_PLAYERS = max(2, int(os.getenv("MATCHMAKING_MIN_PLAYERS", "10")))
MAX_PLAYERS = 10
TOKEN_TTL = int(os.getenv("ASTRO_TOKEN_TTL", str(60 * 60 * 24 * 30)))
MATCH_TTL = int(os.getenv("ASTRO_MATCH_TTL", str(60 * 60 * 6)))
MAX_MATCH_SECONDS = 45 * 60
LANES = ("top", "mid", "bottom")

REALTIME_QUEUES = defaultdict(list)
REALTIME_MATCHES = {}
REALTIME_CONNECTIONS = {}
REALTIME_LOCK = asyncio.Lock()


def now() -> int:
    return int(time.time())


def db_conn():
    conn = sqlite3.connect(DB, timeout=10)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    return conn


def init_db():
    with db_conn() as db:
        db.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL,
                username_key TEXT NOT NULL UNIQUE,
                password_salt TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS profiles (
                user_id INTEGER PRIMARY KEY,
                language TEXT NOT NULL DEFAULT 'Bahasa Indonesia',
                country TEXT NOT NULL DEFAULT 'Indonesia',
                server_region TEXT NOT NULL DEFAULT 'Asia Tenggara',
                profile_complete INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS wallets (
                user_id INTEGER PRIMARY KEY,
                coins INTEGER NOT NULL DEFAULT 2500,
                diamonds INTEGER NOT NULL DEFAULT 100,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS progression (
                user_id INTEGER PRIMARY KEY,
                level INTEGER NOT NULL DEFAULT 1,
                xp INTEGER NOT NULL DEFAULT 0,
                rank TEXT NOT NULL DEFAULT 'Bronze V',
                rank_points INTEGER NOT NULL DEFAULT 0,
                wins INTEGER NOT NULL DEFAULT 0,
                losses INTEGER NOT NULL DEFAULT 0,
                matches INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS inventory (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                item_id TEXT NOT NULL,
                quantity INTEGER NOT NULL DEFAULT 1,
                UNIQUE(user_id, item_id),
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS matches (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                result TEXT NOT NULL,
                duration_seconds INTEGER NOT NULL DEFAULT 0,
                kills INTEGER NOT NULL DEFAULT 0,
                deaths INTEGER NOT NULL DEFAULT 0,
                assists INTEGER NOT NULL DEFAULT 0,
                reward_coins INTEGER NOT NULL DEFAULT 0,
                reward_xp INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS sessions (
                token TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                expires_at INTEGER NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS game_sessions (
                match_id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                status TEXT NOT NULL,
                state_json TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS game_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                match_id TEXT NOT NULL,
                user_id INTEGER NOT NULL,
                action TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                FOREIGN KEY(match_id) REFERENCES game_sessions(match_id) ON DELETE CASCADE,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS identities (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                provider TEXT NOT NULL,
                subject TEXT NOT NULL,
                user_id INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                UNIQUE(provider, subject),
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS oauth_pending (
                nonce TEXT PRIMARY KEY,
                provider TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                user_id INTEGER,
                token TEXT,
                error TEXT,
                created_at INTEGER NOT NULL,
                expires_at INTEGER NOT NULL
            );
            """
        )


def password_hash(password: str, salt_hex: str | None = None):
    salt_hex = salt_hex or secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), salt_hex.encode("ascii"), 210_000
    ).hex()
    return salt_hex, digest


def valid_password(password: str, salt: str, expected: str) -> bool:
    _, digest = password_hash(password, salt)
    return hmac.compare_digest(digest, expected)


def public_state(db, user_id: int):
    user = db.execute("SELECT id, username, created_at FROM users WHERE id=?", (user_id,)).fetchone()
    profile = db.execute("SELECT * FROM profiles WHERE user_id=?", (user_id,)).fetchone()
    wallet = db.execute("SELECT coins, diamonds FROM wallets WHERE user_id=?", (user_id,)).fetchone()
    prog = db.execute(
        "SELECT level, xp, rank, rank_points, wins, losses, matches FROM progression WHERE user_id=?",
        (user_id,),
    ).fetchone()
    items = db.execute(
        "SELECT item_id, quantity FROM inventory WHERE user_id=? ORDER BY item_id", (user_id,)
    ).fetchall()
    return {
        "user": {"id": user["id"], "username": user["username"], "created_at": user["created_at"]},
        "profile": {
            "language": profile["language"],
            "country": profile["country"],
            "server": profile["server_region"],
            "profile_complete": bool(profile["profile_complete"]),
        },
        "wallet": {"coins": wallet["coins"], "diamonds": wallet["diamonds"]},
        "progression": {
            k: prog[k]
            for k in ("level", "xp", "rank", "rank_points", "wins", "losses", "matches")
        },
        "inventory": [{"item_id": row["item_id"], "quantity": row["quantity"]} for row in items],
    }


def require_auth(handler):
    header = handler.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        return None
    token = header[7:].strip()
    if not token:
        return None
    with db_conn() as db:
        row = db.execute(
            "SELECT user_id FROM sessions WHERE token=? AND expires_at>?",
            (token, now()),
        ).fetchone()
        return int(row["user_id"]) if row else None


def new_game_state(match_id: str, user_id: int, mode: str, hero: str, lane: str):
    return {
        "match_id": match_id,
        "user_id": user_id,
        "mode": mode,
        "status": "running",
        "result": None,
        "created_at": now(),
        "last_tick": time.time(),
        "elapsed_seconds": 0,
        "hero": hero,
        "lane": lane if lane in LANES else "mid",
        "target": "enemy_hero",
        "player": {
            "hp": 1000,
            "max_hp": 1000,
            "mana": 500,
            "max_mana": 500,
            "gold": 500,
            "level": 1,
            "alive": True,
            "respawn_at": 0,
            "kills": 0,
            "deaths": 0,
            "assists": 0,
        },
        "enemy_hero": {
            "hp": 1000,
            "max_hp": 1000,
            "alive": True,
            "respawn_at": 0,
        },
        "lanes": {
            lane_name: {
                "ally_minions": 3,
                "enemy_minions": 3,
                "enemy_tower_hp": 1200,
                "enemy_tower_max_hp": 1200,
            }
            for lane_name in LANES
        },
        "enemy_core_hp": 2500,
        "enemy_core_max_hp": 2500,
        "cooldowns": {"skill1": 0, "skill2": 0, "ultimate": 0, "basic": 0},
        "version": 1,
        "last_action": "start",
        "settled": False,
    }


def get_game(db, user_id: int, match_id: str):
    row = db.execute(
        "SELECT match_id, user_id, status, state_json FROM game_sessions WHERE match_id=? AND user_id=?",
        (match_id, user_id),
    ).fetchone()
    if not row:
        return None
    return json.loads(row["state_json"])


def save_game(db, state: dict, event_user_id: int, action: str, payload: dict | None = None):
    ts = now()
    state["version"] = int(state.get("version", 0)) + 1
    db.execute(
        "UPDATE game_sessions SET status=?, state_json=?, updated_at=? WHERE match_id=? AND user_id=?",
        (state["status"], json.dumps(state, separators=(",", ":")), ts, state["match_id"], event_user_id),
    )
    if action != "state_poll":
        db.execute(
            "INSERT INTO game_events(match_id,user_id,action,payload_json,created_at) VALUES(?,?,?,?,?)",
            (state["match_id"], event_user_id, action, json.dumps(payload or {}, separators=(",", ":")), ts),
        )


def clamp(value, low, high):
    return max(low, min(high, value))


def advance_game(state: dict):
    if state["status"] != "running":
        return
    now_f = time.time()
    previous = float(state.get("last_tick", now_f))
    delta = clamp(now_f - previous, 0.0, 10.0)
    if delta <= 0:
        return
    state["last_tick"] = now_f
    state["elapsed_seconds"] = int(state.get("elapsed_seconds", 0) + delta)

    player = state["player"]
    enemy = state["enemy_hero"]
    cds = state["cooldowns"]
    for key in list(cds.keys()):
        cds[key] = max(0, float(cds[key]) - delta)

    if not player["alive"] and state["elapsed_seconds"] >= player["respawn_at"]:
        player["alive"] = True
        player["hp"] = player["max_hp"]
        player["mana"] = player["max_mana"]

    if not enemy["alive"] and state["elapsed_seconds"] >= enemy["respawn_at"]:
        enemy["alive"] = True
        enemy["hp"] = enemy["max_hp"]

    # Server-side enemy pressure. Damage only applies while the player is alive.
    if player["alive"]:
        damage = int(delta * 18)
        player["hp"] = max(0, player["hp"] - damage)
        player["mana"] = min(player["max_mana"], player["mana"] + int(delta * 10))
        if player["hp"] <= 0:
            player["alive"] = False
            player["deaths"] += 1
            player["respawn_at"] = int(state["elapsed_seconds"] + 8)

    # Server-side lane waves slowly damage towers when there are allied minions.
    for lane_name in LANES:
        lane = state["lanes"][lane_name]
        if lane["ally_minions"] > lane["enemy_minions"] and lane["enemy_tower_hp"] > 0:
            lane["enemy_tower_hp"] = max(0, lane["enemy_tower_hp"] - int(delta * 12))
            if lane["enemy_tower_hp"] == 0:
                lane["ally_minions"] = min(5, lane["ally_minions"] + 1)

    if state["enemy_core_hp"] <= 0:
        settle_state(state, True)
    elif state["elapsed_seconds"] >= MAX_MATCH_SECONDS:
        settle_state(state, False)


def settle_state(state: dict, victory: bool):
    if state["status"] != "running":
        return
    state["status"] = "finished"
    state["result"] = "win" if victory else "loss"
    if victory:
        state["player"]["gold"] += 450
    state["last_action"] = "settled"


def action_game(state: dict, action: str, payload: dict):
    if state["status"] != "running":
        return {"ok": False, "error": "match_not_running"}
    advance_game(state)
    if state["status"] != "running":
        return {"ok": True}

    player = state["player"]
    enemy = state["enemy_hero"]
    cds = state["cooldowns"]
    target = str(payload.get("target", state.get("target", "enemy_hero")))
    lane_name = str(payload.get("lane", state.get("lane", "mid")))
    if lane_name in LANES:
        state["lane"] = lane_name
    state["target"] = target if target in ("enemy_hero", "enemy_tower", "enemy_core") else "enemy_hero"

    if action == "set_lane":
        state["last_action"] = "set_lane"
        return {"ok": True}

    if action == "set_target":
        state["last_action"] = "set_target"
        return {"ok": True}

    if action == "push_wave":
        lane = state["lanes"][state["lane"]]
        lane["ally_minions"] = min(5, lane["ally_minions"] + 2)
        lane["enemy_minions"] = max(0, lane["enemy_minions"] - 1)
        if lane["enemy_tower_hp"] > 0:
            lane["enemy_tower_hp"] = max(0, lane["enemy_tower_hp"] - 90)
        state["last_action"] = "push_wave"
        if lane["enemy_tower_hp"] == 0 and state["target"] == "enemy_tower":
            state["target"] = "enemy_core"
        return {"ok": True}

    if action == "recall":
        if not player["alive"]:
            return {"ok": False, "error": "hero_dead"}
        player["hp"] = player["max_hp"]
        player["mana"] = player["max_mana"]
        state["last_action"] = "recall"
        return {"ok": True}

    if not player["alive"]:
        return {"ok": False, "error": "hero_dead"}

    specs = {
        "basic_attack": ("basic", 0, 95),
        "skill1": ("skill1", 60, 180),
        "skill2": ("skill2", 90, 260),
        "ultimate": ("ultimate", 180, 460),
    }
    if action not in specs:
        return {"ok": False, "error": "unknown_action"}
    cd_key, mana_cost, damage = specs[action]
    if float(cds[cd_key]) > 0:
        return {"ok": False, "error": "cooldown", "remaining": round(float(cds[cd_key]), 2)}
    if player["mana"] < mana_cost:
        return {"ok": False, "error": "not_enough_mana"}

    player["mana"] -= mana_cost
    if cd_key == "basic":
        cds[cd_key] = 0.6
    elif cd_key == "skill1":
        cds[cd_key] = 5
    elif cd_key == "skill2":
        cds[cd_key] = 7
    else:
        cds[cd_key] = 14

    target = state["target"]
    if target == "enemy_hero":
        if enemy["alive"]:
            enemy["hp"] = max(0, enemy["hp"] - damage)
            if enemy["hp"] == 0:
                enemy["alive"] = False
                enemy["respawn_at"] = int(state["elapsed_seconds"] + 8)
                player["kills"] += 1
                player["gold"] += 80
    elif target == "enemy_tower":
        lane = state["lanes"][state["lane"]]
        if lane["ally_minions"] <= lane["enemy_minions"]:
            return {"ok": False, "error": "need_minion_wave"}
        lane["enemy_tower_hp"] = max(0, lane["enemy_tower_hp"] - damage)
        player["gold"] += 30 if lane["enemy_tower_hp"] > 0 else 100
        if lane["enemy_tower_hp"] == 0:
            state["target"] = "enemy_core"
    else:
        lane = state["lanes"][state["lane"]]
        if lane["enemy_tower_hp"] > 0:
            return {"ok": False, "error": "enemy_tower_still_alive"}
        state["enemy_core_hp"] = max(0, state["enemy_core_hp"] - damage)
        player["gold"] += 50

    state["last_action"] = action
    if state["enemy_core_hp"] <= 0:
        settle_state(state, True)
    return {"ok": True}


def settle_match_in_db(db, state: dict, user_id: int):
    if state.get("settled", False):
        return None
    result = "win" if state.get("result") == "win" else "loss"
    player = state["player"]
    duration = int(clamp(state.get("elapsed_seconds", 0), 0, MAX_MATCH_SECONDS))
    if result == "win":
        reward_coins, reward_xp = 450, 120
        db.execute(
            "UPDATE wallets SET coins=coins+? WHERE user_id=?", (reward_coins, user_id)
        )
        db.execute(
            "UPDATE progression SET wins=wins+1,matches=matches+1,xp=xp+?,rank_points=rank_points+10 WHERE user_id=?",
            (reward_xp, user_id),
        )
    else:
        reward_coins, reward_xp = 0, 50
        db.execute(
            "UPDATE progression SET losses=losses+1,matches=matches+1,xp=xp+? WHERE user_id=?",
            (reward_xp, user_id),
        )
    row = db.execute("SELECT xp FROM progression WHERE user_id=?", (user_id,)).fetchone()
    while row["xp"] >= 500:
        db.execute("UPDATE progression SET level=level+1,xp=xp-500 WHERE user_id=?", (user_id,))
        row = db.execute("SELECT xp FROM progression WHERE user_id=?", (user_id,)).fetchone()
    existing = db.execute(
        "SELECT 1 FROM matches WHERE user_id=? AND created_at=? AND duration_seconds=? AND result=? LIMIT 1",
        (user_id, state["created_at"], duration, result),
    ).fetchone()
    if not existing:
        db.execute(
            "INSERT INTO matches(user_id,result,duration_seconds,kills,deaths,assists,reward_coins,reward_xp,created_at) VALUES(?,?,?,?,?,?,?,?,?)",
            (
                user_id,
                result,
                duration,
                int(player["kills"]),
                int(player["deaths"]),
                int(player["assists"]),
                reward_coins,
                reward_xp,
                state["created_at"],
            ),
        )
    state["settled"] = True
    return {"coins": reward_coins, "xp": reward_xp}



def provider_config(provider: str):
    p = provider.lower()
    if p == "google":
        return {
            "client_id": os.getenv("GOOGLE_CLIENT_ID", "").strip(),
            "client_secret": os.getenv("GOOGLE_CLIENT_SECRET", "").strip(),
            "redirect_uri": os.getenv("GOOGLE_REDIRECT_URI", "").strip(),
        }
    if p == "facebook":
        return {
            "client_id": os.getenv("FACEBOOK_CLIENT_ID", "").strip(),
            "client_secret": os.getenv("FACEBOOK_CLIENT_SECRET", "").strip(),
            "redirect_uri": os.getenv("FACEBOOK_REDIRECT_URI", "").strip(),
        }
    if p == "whatsapp":
        return {
            "token": os.getenv("WHATSAPP_TOKEN", "").strip(),
            "phone_number_id": os.getenv("WHATSAPP_PHONE_NUMBER_ID", "").strip(),
            "template": os.getenv("WHATSAPP_OTP_TEMPLATE", "").strip(),
        }
    return {}


def provider_ready(provider: str) -> bool:
    cfg = provider_config(provider)
    if provider == "whatsapp":
        return all(cfg.get(k) for k in ("token", "phone_number_id", "template"))
    return all(cfg.get(k) for k in ("client_id", "client_secret", "redirect_uri"))


def http_json(url: str, method: str = "GET", payload=None, headers=None):
    body = None
    hdrs = {"Accept": "application/json", **(headers or {})}
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        hdrs["Content-Type"] = "application/json"
    req = URLRequest(url, data=body, headers=hdrs, method=method)
    with urlopen(req, timeout=10) as resp:
        raw = resp.read().decode("utf-8")
        return json.loads(raw)


def make_social_username(db, display_name: str, email: str, provider: str) -> str:
    base = (display_name or email.split("@")[0] or provider).strip()
    base = "".join(ch for ch in base if ch.isalnum() or ch in "._-")[:16] or provider
    candidate = base
    i = 1
    while db.execute("SELECT 1 FROM users WHERE username_key=?", (candidate.lower(),)).fetchone():
        i += 1
        candidate = f"{base[:max(3, 18-len(str(i)))]}{i}"
    return candidate[:20]


def create_or_link_social_user(provider: str, subject: str, display_name: str, email: str):
    with db_conn() as db:
        identity = db.execute(
            "SELECT user_id FROM identities WHERE provider=? AND subject=?",
            (provider, subject),
        ).fetchone()
        if identity:
            user_id = identity["user_id"]
        else:
            username = make_social_username(db, display_name, email, provider)
            salt = secrets.token_hex(16)
            digest = hashlib.sha256(secrets.token_bytes(32)).hexdigest()
            ts = now()
            cur = db.execute(
                "INSERT INTO users(username, username_key, password_salt, password_hash, created_at, updated_at) VALUES(?,?,?,?,?,?)",
                (username, username.lower(), salt, digest, ts, ts),
            )
            user_id = cur.lastrowid
            db.execute("INSERT INTO profiles(user_id) VALUES(?)", (user_id,))
            db.execute("INSERT INTO wallets(user_id) VALUES(?)", (user_id,))
            db.execute("INSERT INTO progression(user_id) VALUES(?)", (user_id,))
            for item in ("iron_blade", "vital_core", "swift_boots", "arcane_orb"):
                db.execute("INSERT INTO inventory(user_id, item_id, quantity) VALUES(?,?,1)", (user_id, item))
            db.execute(
                "INSERT INTO identities(provider, subject, user_id, created_at) VALUES(?,?,?,?)",
                (provider, subject, user_id, ts),
            )
        token = secrets.token_urlsafe(32)
        ts = now()
        db.execute(
            "INSERT INTO sessions(token,user_id,created_at,expires_at) VALUES(?,?,?,?)",
            (token, user_id, ts, ts + TOKEN_TTL),
        )
        return token, public_state(db, user_id)


def complete_oauth(nonce: str, provider: str, subject: str, display_name: str, email: str):
    token, state = create_or_link_social_user(provider, subject, display_name, email)
    with db_conn() as db:
        db.execute(
            "UPDATE oauth_pending SET status='complete', user_id=?, token=?, error=NULL WHERE nonce=? AND provider=?",
            (state["user"]["id"], token, nonce, provider),
        )


def fail_oauth(nonce: str, message: str):
    with db_conn() as db:
        db.execute("UPDATE oauth_pending SET status='error', error=? WHERE nonce=?", (message, nonce))


def oauth_callback_html(message: str):
    safe = message.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    return f"""<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'><title>Astro Royale</title></head><body style='font-family:sans-serif;background:#050b17;color:white;display:flex;align-items:center;justify-content:center;height:100vh'><div style='max-width:520px;padding:32px;border:1px solid #3fe0ff;border-radius:18px;background:#0b1830'><h2>Astro Royale</h2><p>{safe}</p><p>Kembali ke game. Jendela ini dapat ditutup.</p></div></body></html>"""

class Handler(BaseHTTPRequestHandler):
    server_version = "AstroRoyaleV33/1.0"

    def log_message(self, fmt, *args):
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {self.address_string()} {fmt % args}")

    def respond(self, status: int, payload: dict):
        raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def read_json(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length) if length else b"{}"
            value = json.loads(body.decode("utf-8"))
            if not isinstance(value, dict):
                raise ValueError
            return value
        except Exception:
            raise ValueError("invalid_json")

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        if path == "/health":
            with db_conn() as db:
                users = db.execute("SELECT COUNT(*) n FROM users").fetchone()["n"]
                matches = db.execute("SELECT COUNT(*) n FROM matches").fetchone()["n"]
                active = db.execute("SELECT COUNT(*) n FROM game_sessions WHERE status='running'").fetchone()["n"]
            self.respond(200, {"ok": True, "service": "Astro Royale Backend V35", "users": users, "matches": matches, "active_game_sessions": active, "providers": {"google": provider_ready("google"), "facebook": provider_ready("facebook"), "whatsapp": provider_ready("whatsapp")}, "time": now()})
            return

        # OAuth launcher/callback/poll routes do not require the game bearer token.
        if path.startswith("/api/oauth/"):
            parts = path.strip("/").split("/")
            if len(parts) >= 4:
                provider = parts[2].lower()
                action = parts[3].lower()
                if provider not in ("google", "facebook", "whatsapp"):
                    self.respond(404, {"error": "provider_not_supported"})
                    return
                if action == "start":
                    nonce = str(parse_qs(parsed.query).get("nonce", [secrets.token_urlsafe(18)])[0])
                    if provider == "whatsapp":
                        self.respond(501, {"error": "whatsapp_otp_requires_phone_flow", "provider": provider})
                        return
                    if not provider_ready(provider):
                        self.respond(503, {"error": "provider_not_configured", "provider": provider, "required_env": ["%s_CLIENT_ID" % provider.upper(), "%s_CLIENT_SECRET" % provider.upper(), "%s_REDIRECT_URI" % provider.upper()]})
                        return
                    with db_conn() as db:
                        db.execute("INSERT OR REPLACE INTO oauth_pending(nonce,provider,status,created_at,expires_at) VALUES(?,?, 'pending',?,?)", (nonce, provider, now(), now() + 600))
                    cfg = provider_config(provider)
                    if provider == "google":
                        auth = "https://accounts.google.com/o/oauth2/v2/auth?" + urlencode({"client_id": cfg["client_id"], "redirect_uri": cfg["redirect_uri"], "response_type": "code", "scope": "openid email profile", "access_type": "offline", "state": nonce, "prompt": "select_account"})
                    else:
                        auth = "https://www.facebook.com/v20.0/dialog/oauth?" + urlencode({"client_id": cfg["client_id"], "redirect_uri": cfg["redirect_uri"], "response_type": "code", "scope": "public_profile,email", "state": nonce})
                    self.respond(200, {"ok": True, "provider": provider, "nonce": nonce, "auth_url": auth})
                    return
                if action == "poll":
                    nonce = str(parse_qs(parsed.query).get("nonce", [""])[0])
                    with db_conn() as db:
                        row = db.execute("SELECT * FROM oauth_pending WHERE nonce=?", (nonce,)).fetchone()
                        if not row:
                            self.respond(404, {"error": "oauth_session_not_found"})
                            return
                        if row["expires_at"] < now():
                            self.respond(410, {"error": "oauth_session_expired"})
                            return
                        result = {"ok": True, "status": row["status"]}
                        if row["status"] == "complete" and row["user_id"]:
                            result["token"] = row["token"]
                            result.update(public_state(db, row["user_id"]))
                        if row["status"] == "error":
                            result["error"] = row["error"]
                    self.respond(200, result)
                    return
                if action == "callback":
                    code = str(parse_qs(parsed.query).get("code", [""])[0])
                    state = str(parse_qs(parsed.query).get("state", [""])[0])
                    if not code or not state:
                        self.respond(400, {"error": "missing_code_or_state"})
                        return
                    with db_conn() as db:
                        pending = db.execute("SELECT * FROM oauth_pending WHERE nonce=? AND provider=?", (state, provider)).fetchone()
                    if not pending:
                        self.respond(400, {"error": "invalid_oauth_state"})
                        return
                    try:
                        cfg = provider_config(provider)
                        if provider == "google":
                            token_data = http_json("https://oauth2.googleapis.com/token", "POST", {"code": code, "client_id": cfg["client_id"], "client_secret": cfg["client_secret"], "redirect_uri": cfg["redirect_uri"], "grant_type": "authorization_code"})
                            info = http_json("https://openidconnect.googleapis.com/v1/userinfo", headers={"Authorization": "Bearer " + str(token_data["access_token"])})
                            subject = str(info.get("sub", "")); display = str(info.get("name", "")); email = str(info.get("email", ""))
                        else:
                            token_url = "https://graph.facebook.com/v20.0/oauth/access_token?" + urlencode({"client_id": cfg["client_id"], "client_secret": cfg["client_secret"], "redirect_uri": cfg["redirect_uri"], "code": code})
                            token_data = http_json(token_url)
                            access = str(token_data["access_token"])
                            info = http_json("https://graph.facebook.com/me?" + urlencode({"fields": "id,name,email", "access_token": access}))
                            subject = str(info.get("id", "")); display = str(info.get("name", "")); email = str(info.get("email", ""))
                        if not subject:
                            raise RuntimeError("provider_user_id_missing")
                        complete_oauth(state, provider, subject, display, email)
                        body = oauth_callback_html("Login %s berhasil. Kamu bisa kembali ke Astro Royale." % provider.capitalize())
                        self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8"); self.send_header("Content-Length", str(len(body.encode()))); self.end_headers(); self.wfile.write(body.encode())
                    except Exception as exc:
                        fail_oauth(state, str(exc))
                        self.respond(502, {"error": "oauth_exchange_failed", "detail": str(exc)})
                    return
            self.respond(404, {"error": "oauth_route_not_found"})
            return

        user_id = require_auth(self)
        if user_id is None:
            self.respond(401, {"error": "unauthorized"})
            return

        if path == "/api/game/state":
            qs = parse_qs(parsed.query)
            match_id = str(qs.get("match_id", [""])[0])
            with db_conn() as db:
                state = get_game(db, user_id, match_id)
                if state is None:
                    self.respond(404, {"error": "match_not_found"})
                    return
                advance_game(state)
                reward = None
                if state["status"] == "finished":
                    reward = settle_match_in_db(db, state, user_id)
                save_game(db, state, user_id, "state_poll", {})
                payload = {"ok": True, "state": state, "profile": public_state(db, user_id), "reward": reward}
            self.respond(200, payload)
            return

        with db_conn() as db:
            if path == "/api/me":
                self.respond(200, {"ok": True, **public_state(db, user_id)})
                return
            if path == "/api/me/matches":
                rows = db.execute(
                    "SELECT id, result, duration_seconds, kills, deaths, assists, reward_coins, reward_xp, created_at "
                    "FROM matches WHERE user_id=? ORDER BY id DESC LIMIT 100",
                    (user_id,),
                ).fetchall()
                self.respond(200, {"ok": True, "matches": [dict(r) for r in rows]})
                return

        self.respond(404, {"error": "not_found"})

    def do_POST(self):
        path = urlparse(self.path).path
        try:
            data = self.read_json()
        except ValueError:
            self.respond(400, {"error": "invalid_json"})
            return

        if path == "/api/account/register":
            username = str(data.get("username", "")).strip()
            password = str(data.get("password", ""))
            if len(username) < 3 or len(username) > 20 or len(password) < 8:
                self.respond(400, {"error": "invalid_credentials"})
                return
            key = username.lower()
            salt, digest = password_hash(password)
            ts = now()
            try:
                with db_conn() as db:
                    cur = db.execute(
                        "INSERT INTO users(username, username_key, password_salt, password_hash, created_at, updated_at) VALUES(?,?,?,?,?,?)",
                        (username, key, salt, digest, ts, ts),
                    )
                    user_id = cur.lastrowid
                    db.execute("INSERT INTO profiles(user_id) VALUES(?)", (user_id,))
                    db.execute("INSERT INTO wallets(user_id) VALUES(?)", (user_id,))
                    db.execute("INSERT INTO progression(user_id) VALUES(?)", (user_id,))
                    for item in ("iron_blade", "vital_core", "swift_boots", "arcane_orb"):
                        db.execute("INSERT INTO inventory(user_id, item_id, quantity) VALUES(?,?,1)", (user_id, item))
                    token = secrets.token_urlsafe(32)
                    db.execute(
                        "INSERT INTO sessions(token,user_id,created_at,expires_at) VALUES(?,?,?,?)",
                        (token, user_id, ts, ts + TOKEN_TTL),
                    )
                    state = public_state(db, user_id)
                self.respond(201, {"ok": True, "token": token, **state})
            except sqlite3.IntegrityError:
                self.respond(409, {"error": "already_exists"})
            return

        if path == "/api/account/login":
            username = str(data.get("username", "")).strip()
            password = str(data.get("password", ""))
            with db_conn() as db:
                user = db.execute(
                    "SELECT id, username, password_salt, password_hash FROM users WHERE username_key=?",
                    (username.lower(),),
                ).fetchone()
                if not user or not valid_password(password, user["password_salt"], user["password_hash"]):
                    self.respond(401, {"error": "invalid_credentials"})
                    return
                token = secrets.token_urlsafe(32)
                ts = now()
                db.execute(
                    "INSERT INTO sessions(token,user_id,created_at,expires_at) VALUES(?,?,?,?)",
                    (token, user["id"], ts, ts + TOKEN_TTL),
                )
                state = public_state(db, user["id"])
            self.respond(200, {"ok": True, "token": token, **state})
            return

        if path == "/api/auth/whatsapp/request":
            if not provider_ready("whatsapp"):
                self.respond(503, {"error": "whatsapp_not_configured", "required_env": ["WHATSAPP_TOKEN", "WHATSAPP_PHONE_NUMBER_ID", "WHATSAPP_OTP_TEMPLATE"]})
                return
            self.respond(501, {"error": "whatsapp_otp_flow_requires_phone_ui_and_template_parameters"})
            return

        user_id = require_auth(self)
        if user_id is None:
            self.respond(401, {"error": "unauthorized"})
            return

        if path == "/api/account/logout":
            token = self.headers.get("Authorization", "")[7:].strip()
            with db_conn() as db:
                db.execute("DELETE FROM sessions WHERE token=?", (token,))
            self.respond(200, {"ok": True})
            return

        if path == "/api/game/start":
            mode = str(data.get("mode", "Classic 5v5 AI"))[:40]
            hero = str(data.get("hero", "Astra"))[:40]
            lane = str(data.get("lane", "mid"))
            match_id = secrets.token_urlsafe(16)
            state = new_game_state(match_id, user_id, mode, hero, lane)
            with db_conn() as db:
                db.execute(
                    "INSERT INTO game_sessions(match_id,user_id,status,state_json,created_at,updated_at) VALUES(?,?,?,?,?,?)",
                    (match_id, user_id, "running", json.dumps(state, separators=(",", ":")), now(), now()),
                )
                db.execute(
                    "INSERT INTO game_events(match_id,user_id,action,payload_json,created_at) VALUES(?,?,?,?,?)",
                    (match_id, user_id, "start", json.dumps(data, separators=(",", ":")), now()),
                )
            self.respond(201, {"ok": True, "state": state})
            return

        if path == "/api/game/action":
            match_id = str(data.get("match_id", ""))
            action = str(data.get("action", ""))
            with db_conn() as db:
                state = get_game(db, user_id, match_id)
                if state is None:
                    self.respond(404, {"error": "match_not_found"})
                    return
                if state["status"] != "running":
                    self.respond(409, {"error": "match_not_running", "state": state})
                    return
                result = action_game(state, action, data)
                if not result.get("ok"):
                    self.respond(409, {"error": result.get("error", "action_rejected"), "details": result, "state": state})
                    return
                reward = None
                if state["status"] == "finished":
                    reward = settle_match_in_db(db, state, user_id)
                save_game(db, state, user_id, action, data)
                self.respond(200, {"ok": True, "state": state, "reward": reward, "profile": public_state(db, user_id)})
            return

        self.respond(404, {"error": "not_found"})

    def do_PUT(self):
        path = urlparse(self.path).path
        try:
            data = self.read_json()
        except ValueError:
            self.respond(400, {"error": "invalid_json"})
            return
        user_id = require_auth(self)
        if user_id is None:
            self.respond(401, {"error": "unauthorized"})
            return

        if path == "/api/me/profile":
            language = str(data.get("language", "Bahasa Indonesia")).strip()[:40]
            country = str(data.get("country", "Indonesia")).strip()[:40]
            server_region = str(data.get("server", "Asia Tenggara")).strip()[:40]
            username = str(data.get("username", "")).strip()[:20]
            if len(username) < 3:
                self.respond(400, {"error": "invalid_username"})
                return
            try:
                with db_conn() as db:
                    existing = db.execute(
                        "SELECT id FROM users WHERE username_key=? AND id<>?",
                        (username.lower(), user_id),
                    ).fetchone()
                    if existing:
                        self.respond(409, {"error": "username_taken"})
                        return
                    db.execute(
                        "UPDATE users SET username=?, username_key=?, updated_at=? WHERE id=?",
                        (username, username.lower(), now(), user_id),
                    )
                    db.execute(
                        "UPDATE profiles SET language=?, country=?, server_region=?, profile_complete=1 WHERE user_id=?",
                        (language, country, server_region, user_id),
                    )
                    state = public_state(db, user_id)
                self.respond(200, {"ok": True, **state})
            except sqlite3.IntegrityError:
                self.respond(409, {"error": "username_taken"})
            return

        self.respond(404, {"error": "not_found"})



def auth_user_from_token(token: str):
    if not token:
        return None
    with db_conn() as db:
        row = db.execute(
            "SELECT user_id FROM sessions WHERE token=? AND expires_at>?",
            (token, now()),
        ).fetchone()
        return int(row["user_id"]) if row else None


def realtime_player_snapshot(player):
    return {
        "user_id": player["user_id"],
        "username": player["username"],
        "team": player["team"],
        "slot": player["slot"],
        "hero": player["hero"],
        "lane": player["lane"],
        "x": round(float(player["x"]), 2),
        "y": round(float(player["y"]), 2),
        "hp": int(player["hp"]),
        "max_hp": int(player["max_hp"]),
        "mana": int(player["mana"]),
        "max_mana": int(player["max_mana"]),
        "gold": int(player["gold"]),
        "alive": bool(player["alive"]),
        "kills": int(player["kills"]),
        "deaths": int(player["deaths"]),
        "assists": int(player["assists"]),
        "connected": bool(player.get("connected", True)),
    }


def realtime_state(match):
    return {
        "match_id": match["match_id"],
        "status": match["status"],
        "version": match["version"],
        "elapsed_seconds": int(time.time() - match["started_at"]),
        "server_time": time.time(),
        "tick_hz": 10,
        "players": [realtime_player_snapshot(p) for p in match["players"].values()],
        "cores": dict(match["cores"]),
        "towers": {team: dict(lanes) for team, lanes in match["towers"].items()},
        "objectives": dict(match["objectives"]),
        "winner": match.get("winner"),
        "reason": match.get("reason", ""),
    }


def make_realtime_match(entries):
    match_id = "rt_" + secrets.token_urlsafe(12)
    players = {}
    lanes_by_slot = ["top", "mid", "bottom", "top", "bottom", "top", "mid", "bottom", "top", "mid"]
    for idx, entry in enumerate(entries[:MAX_PLAYERS]):
        team = "blue" if idx < 5 else "red"
        user_id = entry["user_id"]
        lane = entry.get("lane") if entry.get("lane") in LANES else lanes_by_slot[idx]
        with db_conn() as db:
            row = db.execute("SELECT username FROM users WHERE id=?", (user_id,)).fetchone()
            username = row["username"] if row else entry.get("username", f"Player{idx+1}")
        players[str(user_id)] = {
            "user_id": user_id, "username": username, "team": team, "slot": idx + 1,
            "hero": entry.get("hero", "Astra"), "lane": lane,
            "x": 160.0 if team == "blue" else 1120.0, "y": 360.0 + ((idx % 5) - 2) * 46,
            "hp": 1000, "max_hp": 1000, "mana": 500, "max_mana": 500,
            "gold": 500, "alive": True, "respawn_at": 0.0,
            "kills": 0, "deaths": 0, "assists": 0,
            "connected": True, "disconnected_at": None,
            "last_action_at": 0.0,
        }
    return {
        "match_id": match_id,
        "status": "starting",
        "version": 1,
        "started_at": time.time(),
        "players": players,
        "cores": {"blue": 10000, "red": 10000},
        "towers": {"blue": {"top": 1200, "mid": 1200, "bottom": 1200}, "red": {"top": 1200, "mid": 1200, "bottom": 1200}},
        "objectives": {"turtle": 0, "lord": 0},
        "winner": None,
        "reason": "",
        "sockets": {},
        "settled": False,
    }


async def ws_send(ws, payload):
    try:
        await ws.send(json.dumps(payload, separators=(",", ":")))
    except Exception:
        pass


async def broadcast_match(match, payload):
    if payload.get("type") != "match_state":
        await asyncio.gather(*[ws_send(ws, payload) for ws in list(match["sockets"].values())], return_exceptions=True)
        return
    state_payload = {"type": "match_state", "state": realtime_state(match)}
    await asyncio.gather(*[ws_send(ws, state_payload) for ws in list(match["sockets"].values())], return_exceptions=True)


def settle_realtime_player(user_id: int, win: bool, state: dict):
    duration = int(max(0, time.time() - state["started_at"]))
    with db_conn() as db:
        p = state["players"].get(str(user_id))
        if not p:
            return
        reward_coins = 450 if win else 50
        reward_xp = 120 if win else 50
        result = "win" if win else "loss"
        db.execute(
            "INSERT INTO matches(user_id,result,duration_seconds,kills,deaths,assists,reward_coins,reward_xp,created_at) VALUES(?,?,?,?,?,?,?,?,?)",
            (user_id, result, duration, p["kills"], p["deaths"], p["assists"], reward_coins, reward_xp, now()),
        )
        db.execute(
            "UPDATE progression SET matches=matches+1, wins=wins+?, losses=losses+?, xp=xp+?, rank_points=MAX(0, rank_points+?) WHERE user_id=?",
            (1 if win else 0, 0 if win else 1, reward_xp, 10 if win else -3, user_id),
        )
        db.execute("UPDATE wallets SET coins=coins+? WHERE user_id=?", (reward_coins, user_id))
        db.execute("UPDATE users SET updated_at=? WHERE id=?", (now(), user_id))
        row = db.execute("SELECT level,xp FROM progression WHERE user_id=?", (user_id,)).fetchone()
        if row and row["xp"] >= 500:
            db.execute("UPDATE progression SET level=level+1,xp=xp-500 WHERE user_id=?", (user_id,))


async def realtime_tick_loop():
    while True:
        await asyncio.sleep(0.1)
        async with REALTIME_LOCK:
            matches = list(REALTIME_MATCHES.values())
        for match in matches:
            if match["status"] not in ("starting", "running"):
                continue
            match["status"] = "running"
            match["version"] += 1
            now_f = time.time()
            # Respawn and passive mana regeneration are authoritative.
            for p in match["players"].values():
                if not p["alive"] and now_f >= p["respawn_at"]:
                    p["alive"] = True
                    p["hp"] = p["max_hp"]
                    p["mana"] = p["max_mana"]
                if p["alive"]:
                    p["mana"] = min(p["max_mana"], p["mana"] + 2)
            await broadcast_match(match, {"type": "match_state"})


async def handle_ws(ws):
    user_id = None
    subscribed_match = None
    try:
        raw = await asyncio.wait_for(ws.recv(), timeout=12)
        msg = json.loads(raw)
        if msg.get("type") != "auth":
            await ws_send(ws, {"type": "error", "error": "auth_required"})
            return
        user_id = auth_user_from_token(str(msg.get("token", "")))
        if not user_id:
            await ws_send(ws, {"type": "error", "error": "unauthorized"})
            return
        REALTIME_CONNECTIONS[user_id] = ws
        await ws_send(ws, {"type": "auth_ok", "user_id": user_id})
        async for raw in ws:
            try:
                msg = json.loads(raw)
            except Exception:
                await ws_send(ws, {"type": "error", "error": "invalid_json"})
                continue
            mtype = str(msg.get("type", ""))
            if mtype == "resume_match":
                match_id = str(msg.get("match_id", ""))
                match = REALTIME_MATCHES.get(match_id)
                player = match["players"].get(str(user_id)) if match else None
                if not match or not player or match.get("status") == "finished":
                    await ws_send(ws, {"type": "resume_failed", "match_id": match_id, "reason": "match_unavailable"})
                    continue
                match["sockets"][str(user_id)] = ws
                player["connected"] = True
                player["disconnected_at"] = None
                await ws_send(ws, {
                    "type": "resume_ok",
                    "match_id": match_id,
                    "team": player["team"],
                    "slot": player["slot"],
                    "state": realtime_state(match),
                })
                await broadcast_match(match, {"type": "match_state"})
                continue
            if mtype == "join_queue":
                mode = str(msg.get("mode", "Classic 5v5"))[:40]
                hero = str(msg.get("hero", "Astra"))[:40]
                lane = str(msg.get("lane", "mid")) if str(msg.get("lane", "mid")) in LANES else "mid"
                key = f"{mode}|default"
                # Avoid duplicate queue entries.
                REALTIME_QUEUES[key] = [e for e in REALTIME_QUEUES[key] if e["user_id"] != user_id]
                entry = {"user_id": user_id, "hero": hero, "lane": lane}
                REALTIME_QUEUES[key].append(entry)
                await ws_send(ws, {"type": "queue_status", "queued": len(REALTIME_QUEUES[key]), "required": MIN_PLAYERS})
                if len(REALTIME_QUEUES[key]) >= MIN_PLAYERS:
                    entries = REALTIME_QUEUES[key][:MAX_PLAYERS]
                    del REALTIME_QUEUES[key][:len(entries)]
                    match = make_realtime_match(entries)
                    async with REALTIME_LOCK:
                        REALTIME_MATCHES[match["match_id"]] = match
                    for ent in entries:
                        conn = REALTIME_CONNECTIONS.get(ent["user_id"])
                        if conn is not None:
                            match["sockets"][str(ent["user_id"])] = conn
                    for ent in entries:
                        conn = REALTIME_CONNECTIONS.get(ent["user_id"])
                        if conn is not None:
                            team = match["players"][str(ent["user_id"])]["team"]
                            await ws_send(conn, {"type": "match_found", "match_id": match["match_id"], "team": team, "slot": match["players"][str(ent["user_id"])]["slot"], "required": MAX_PLAYERS, "state": realtime_state(match)})
                    await broadcast_match(match, {"type": "match_state"})
                continue
            if mtype == "leave_queue":
                for key in list(REALTIME_QUEUES.keys()):
                    REALTIME_QUEUES[key] = [e for e in REALTIME_QUEUES[key] if e["user_id"] != user_id]
                await ws_send(ws, {"type": "queue_left"})
                continue
            if mtype == "action":
                match_id = str(msg.get("match_id", ""))
                match = REALTIME_MATCHES.get(match_id)
                if not match:
                    await ws_send(ws, {"type": "error", "error": "match_not_found"})
                    continue
                player = match["players"].get(str(user_id))
                if not player:
                    await ws_send(ws, {"type": "error", "error": "not_in_match"})
                    continue
                action = str(msg.get("action", ""))
                now_f = time.time()
                if now_f - float(player.get("last_action_at", 0)) < 0.05:
                    await ws_send(ws, {"type": "action_rejected", "reason": "rate_limited"})
                    continue
                player["last_action_at"] = now_f
                if action == "move":
                    player["x"] = max(0.0, min(1280.0, float(msg.get("x", player["x"]))))
                    player["y"] = max(0.0, min(720.0, float(msg.get("y", player["y"]))))
                elif not player["alive"]:
                    await ws_send(ws, {"type": "action_rejected", "reason": "dead"})
                    continue
                elif action in ("basic_attack", "skill1", "skill2", "ultimate"):
                    target_id = str(msg.get("target_user_id", ""))
                    target = match["players"].get(target_id)
                    if target and target["team"] != player["team"] and target["alive"]:
                        damage = {"basic_attack": 90, "skill1": 180, "skill2": 240, "ultimate": 420}[action]
                        target["hp"] = max(0, target["hp"] - damage)
                        player["gold"] += 20
                        if target["hp"] <= 0:
                            target["alive"] = False
                            target["deaths"] += 1
                            target["respawn_at"] = now_f + 8.0
                            player["kills"] += 1
                    else:
                        lane = str(msg.get("lane", player["lane"])) if str(msg.get("lane", player["lane"])) in LANES else player["lane"]
                        if action == "basic_attack": damage = 75
                        elif action == "skill1": damage = 150
                        elif action == "skill2": damage = 220
                        else: damage = 380
                        enemy_team = "red" if player["team"] == "blue" else "blue"
                        tower_hp = match["towers"][enemy_team][lane]
                        if tower_hp > 0:
                            match["towers"][enemy_team][lane] = max(0, tower_hp - damage)
                        else:
                            match["cores"][enemy_team] = max(0, match["cores"][enemy_team] - damage)
                        player["gold"] += 30
                elif action == "recall":
                    player["hp"] = player["max_hp"]
                    player["mana"] = player["max_mana"]
                elif action == "objective":
                    enemy_team = "red" if player["team"] == "blue" else "blue"
                    match["objectives"]["turtle"] += 1
                    player["gold"] += 50
                else:
                    await ws_send(ws, {"type": "action_rejected", "reason": "unknown_action"})
                    continue

                # Victory is server-owned.
                if match["cores"]["red"] <= 0 or match["cores"]["blue"] <= 0:
                    match["status"] = "finished"
                    match["winner"] = "blue" if match["cores"]["red"] <= 0 else "red"
                    match["reason"] = "enemy_core_destroyed"
                    winner_team = match["winner"]
                    if not match["settled"]:
                        match["settled"] = True
                        for p in match["players"].values():
                            settle_realtime_player(p["user_id"], p["team"] == winner_team, match)
                await broadcast_match(match, {"type": "match_state"})
                continue
            if mtype == "ping":
                await ws_send(ws, {"type": "pong", "server_time": time.time()})
    except Exception:
        pass
    finally:
        # A reconnect may already have installed a newer socket for this account.
        # Only the currently registered socket is allowed to clear queue/session presence.
        if user_id and REALTIME_CONNECTIONS.get(user_id) is ws:
            REALTIME_CONNECTIONS.pop(user_id, None)
            for key in list(REALTIME_QUEUES.keys()):
                REALTIME_QUEUES[key] = [e for e in REALTIME_QUEUES[key] if e["user_id"] != user_id]
            for match in REALTIME_MATCHES.values():
                player = match.get("players", {}).get(str(user_id))
                if player:
                    player["connected"] = False
                    player["disconnected_at"] = time.time()
                if match.get("sockets", {}).get(str(user_id)) is ws:
                    match["sockets"].pop(str(user_id), None)
                    await broadcast_match(match, {"type": "match_state"})


async def ws_server_main():
    if serve is None:
        raise RuntimeError("websockets package is required for V35 realtime server")
    async with serve(handle_ws, HOST, WS_PORT, ping_interval=10, ping_timeout=20, max_size=1_000_000):
        print(f"Astro Royale V35 realtime WebSocket on ws://{HOST}:{WS_PORT}/ws")
        await realtime_tick_loop()


def start_ws_thread():
    if serve is None:
        print("WARNING: Python package 'websockets' is not installed; HTTP backend still works, realtime V35 disabled.")
        return None
    def runner():
        try:
            asyncio.run(ws_server_main())
        except Exception as exc:
            print(f"Realtime WebSocket stopped: {exc}")
    t = threading.Thread(target=runner, daemon=True, name="AstroRealtimeWS")
    t.start()
    return t

if __name__ == "__main__":
    init_db()
    print(f"Astro Royale V35 backend listening on http://{HOST}:{PORT}")
    print(f"Database: {DB.resolve()}")
    start_ws_thread()
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
