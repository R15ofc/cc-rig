from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any, Optional

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field


BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = Path(os.environ.get("RIG_DB", BASE_DIR / "rig.db"))
PACKAGES_DIR = Path(os.environ.get("RIG_PACKAGES_DIR", BASE_DIR / "packages")).resolve()
STATIC_DIR = Path(__file__).resolve().parent / "static"
APP_VERSION = "0.1.0"
SAFE_COMMANDS = {
    "ping",
    "reboot",
    "shutdown",
    "install",
    "remove",
    "upgrade",
    "start_app",
    "stop_app",
    "restart_app",
    "set_label",
    "send_log",
}


def now() -> float:
    return time.time()


def connect() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def encode_json(value: Any) -> str:
    return json.dumps(value, separators=(",", ":"), sort_keys=True)


def decode_json(value: Optional[str], default: Any = None) -> Any:
    if value is None or value == "":
        return default
    return json.loads(value)


def init_db() -> None:
    with connect() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS api_keys (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                token_hash TEXT NOT NULL UNIQUE,
                created_at REAL NOT NULL,
                last_used_at REAL
            );

            CREATE TABLE IF NOT EXISTS devices (
                computer_id INTEGER PRIMARY KEY,
                label TEXT,
                device_type TEXT NOT NULL,
                agent_version TEXT NOT NULL,
                token_hash TEXT NOT NULL,
                status TEXT NOT NULL,
                first_seen REAL NOT NULL,
                last_seen REAL NOT NULL,
                latest_telemetry TEXT
            );

            CREATE TABLE IF NOT EXISTS telemetry (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                computer_id INTEGER NOT NULL,
                ts REAL NOT NULL,
                data TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                computer_id INTEGER NOT NULL,
                ts REAL NOT NULL,
                level TEXT NOT NULL,
                app TEXT NOT NULL,
                message TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS commands (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                computer_id INTEGER,
                command TEXT NOT NULL,
                payload TEXT NOT NULL,
                status TEXT NOT NULL,
                result TEXT,
                error TEXT,
                created_at REAL NOT NULL,
                sent_at REAL,
                completed_at REAL
            );

            CREATE TABLE IF NOT EXISTS packages (
                name TEXT NOT NULL,
                version TEXT NOT NULL,
                description TEXT NOT NULL,
                manifest TEXT NOT NULL,
                created_at REAL NOT NULL,
                PRIMARY KEY (name, version)
            );

            CREATE TABLE IF NOT EXISTS installs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                computer_id INTEGER NOT NULL,
                package_name TEXT NOT NULL,
                version TEXT NOT NULL,
                installed_at REAL NOT NULL,
                UNIQUE (computer_id, package_name)
            );

            CREATE TABLE IF NOT EXISTS alerts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                computer_id INTEGER,
                level TEXT NOT NULL,
                message TEXT NOT NULL,
                resolved INTEGER NOT NULL DEFAULT 0,
                created_at REAL NOT NULL,
                resolved_at REAL
            );
            """
        )


def seed_packages() -> None:
    if not PACKAGES_DIR.exists():
        return
    with connect() as conn:
        for manifest_path in PACKAGES_DIR.glob("*/*/manifest.json"):
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            name = manifest["name"]
            version = manifest["version"]
            description = manifest.get("description", "")
            conn.execute(
                """
                INSERT INTO packages (name, version, description, manifest, created_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(name, version) DO UPDATE SET
                    description = excluded.description,
                    manifest = excluded.manifest
                """,
                (name, version, description, encode_json(manifest), now()),
            )


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    seed_packages()
    yield


app = FastAPI(title="RIG Hub", version=APP_VERSION, lifespan=lifespan)
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


class RegisterRequest(BaseModel):
    computer_id: int
    label: Optional[str] = None
    device_type: str = "computer"
    agent_version: str
    token: str = Field(min_length=1)


class HeartbeatRequest(BaseModel):
    computer_id: int
    uptime: float
    status: str
    agent_version: str


class TelemetryRequest(BaseModel):
    computer_id: int
    data: dict[str, Any]


class LogEntry(BaseModel):
    ts: float
    level: str
    app: str
    message: str


class LogsRequest(BaseModel):
    computer_id: int
    entries: list[LogEntry]


class CommandCreateRequest(BaseModel):
    computer_id: Optional[int] = None
    command: str
    payload: dict[str, Any] = Field(default_factory=dict)


class CommandResultRequest(BaseModel):
    computer_id: Optional[int] = None
    status: str = "done"
    result: dict[str, Any] = Field(default_factory=dict)
    error: Optional[str] = None


def require_bearer(authorization: Optional[str] = Header(default=None)) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    raw_token = authorization.split(" ", 1)[1].strip()
    hashed = token_hash(raw_token)
    with connect() as conn:
        row = conn.execute("SELECT id FROM api_keys WHERE token_hash = ?", (hashed,)).fetchone()
        if row is None:
            raise HTTPException(status_code=401, detail="Invalid bearer token")
        conn.execute("UPDATE api_keys SET last_used_at = ? WHERE id = ?", (now(), row["id"]))
    return hashed


def device_dict(row: sqlite3.Row) -> dict[str, Any]:
    data = dict(row)
    data["latest_telemetry"] = decode_json(data.get("latest_telemetry"), None)
    data["online"] = now() - float(data["last_seen"]) <= 15
    return data


def command_dict(row: sqlite3.Row) -> dict[str, Any]:
    data = dict(row)
    data["payload"] = decode_json(data.get("payload"), {})
    data["result"] = decode_json(data.get("result"), None)
    return data


def package_dict(row: sqlite3.Row, include_manifest: bool = False) -> dict[str, Any]:
    data = dict(row)
    if include_manifest:
        data["manifest"] = decode_json(data["manifest"], {})
    else:
        data.pop("manifest", None)
    return data


def latest_package_row(conn: sqlite3.Connection, name: str) -> Optional[sqlite3.Row]:
    return conn.execute(
        "SELECT * FROM packages WHERE name = ? ORDER BY version DESC LIMIT 1",
        (name,),
    ).fetchone()


@app.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/health")
def health() -> dict[str, Any]:
    return {"ok": True, "version": APP_VERSION, "time": now()}


@app.post("/api/register")
def register(payload: RegisterRequest) -> dict[str, Any]:
    hashed = token_hash(payload.token)
    current = now()
    with connect() as conn:
        conn.execute(
            "INSERT OR IGNORE INTO api_keys (token_hash, created_at) VALUES (?, ?)",
            (hashed, current),
        )
        existing = conn.execute(
            "SELECT first_seen FROM devices WHERE computer_id = ?",
            (payload.computer_id,),
        ).fetchone()
        first_seen = existing["first_seen"] if existing else current
        conn.execute(
            """
            INSERT INTO devices (
                computer_id, label, device_type, agent_version, token_hash,
                status, first_seen, last_seen, latest_telemetry
            )
            VALUES (?, ?, ?, ?, ?, 'online', ?, ?, NULL)
            ON CONFLICT(computer_id) DO UPDATE SET
                label = excluded.label,
                device_type = excluded.device_type,
                agent_version = excluded.agent_version,
                token_hash = excluded.token_hash,
                status = 'online',
                last_seen = excluded.last_seen
            """,
            (
                payload.computer_id,
                payload.label,
                payload.device_type,
                payload.agent_version,
                hashed,
                first_seen,
                current,
            ),
        )
    return {"ok": True, "computer_id": payload.computer_id}


@app.post("/api/heartbeat")
def heartbeat(payload: HeartbeatRequest, _: str = Depends(require_bearer)) -> dict[str, Any]:
    current = now()
    with connect() as conn:
        result = conn.execute(
            """
            UPDATE devices
            SET status = ?, agent_version = ?, last_seen = ?
            WHERE computer_id = ?
            """,
            (payload.status, payload.agent_version, current, payload.computer_id),
        )
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="Device is not registered")
    return {"ok": True}


@app.post("/api/telemetry")
def telemetry(payload: TelemetryRequest, _: str = Depends(require_bearer)) -> dict[str, Any]:
    current = now()
    encoded = encode_json(payload.data)
    with connect() as conn:
        conn.execute(
            "INSERT INTO telemetry (computer_id, ts, data) VALUES (?, ?, ?)",
            (payload.computer_id, current, encoded),
        )
        conn.execute(
            """
            UPDATE devices
            SET latest_telemetry = ?, last_seen = ?, status = 'online'
            WHERE computer_id = ?
            """,
            (encoded, current, payload.computer_id),
        )
    return {"ok": True}


@app.post("/api/logs")
def logs(payload: LogsRequest, _: str = Depends(require_bearer)) -> dict[str, Any]:
    rows = [
        (payload.computer_id, entry.ts, entry.level, entry.app, entry.message)
        for entry in payload.entries
    ]
    with connect() as conn:
        conn.executemany(
            """
            INSERT INTO logs (computer_id, ts, level, app, message)
            VALUES (?, ?, ?, ?, ?)
            """,
            rows,
        )
    return {"ok": True, "count": len(rows)}


@app.get("/api/devices")
def devices() -> list[dict[str, Any]]:
    with connect() as conn:
        rows = conn.execute("SELECT * FROM devices ORDER BY last_seen DESC").fetchall()
    return [device_dict(row) for row in rows]


@app.get("/api/devices/{computer_id}")
def device(computer_id: int) -> dict[str, Any]:
    with connect() as conn:
        row = conn.execute("SELECT * FROM devices WHERE computer_id = ?", (computer_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Device not found")
    return device_dict(row)


@app.get("/api/devices/{computer_id}/telemetry")
def device_telemetry(computer_id: int, limit: int = 50) -> list[dict[str, Any]]:
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT id, computer_id, ts, data
            FROM telemetry
            WHERE computer_id = ?
            ORDER BY ts DESC
            LIMIT ?
            """,
            (computer_id, min(max(limit, 1), 500)),
        ).fetchall()
    return [{**dict(row), "data": decode_json(row["data"], {})} for row in rows]


@app.get("/api/devices/{computer_id}/logs")
def device_logs(computer_id: int, limit: int = 200) -> list[dict[str, Any]]:
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT * FROM logs
            WHERE computer_id = ?
            ORDER BY ts DESC, id DESC
            LIMIT ?
            """,
            (computer_id, min(max(limit, 1), 1000)),
        ).fetchall()
    return [dict(row) for row in rows]


@app.get("/api/commands/poll")
def poll_commands(computer_id: int, _: str = Depends(require_bearer)) -> list[dict[str, Any]]:
    current = now()
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT * FROM commands
            WHERE status = 'queued' AND (computer_id IS NULL OR computer_id = ?)
            ORDER BY created_at ASC
            LIMIT 10
            """,
            (computer_id,),
        ).fetchall()
        ids = [row["id"] for row in rows]
        if ids:
            placeholders = ",".join("?" for _ in ids)
            conn.execute(
                f"UPDATE commands SET status = 'sent', sent_at = ? WHERE id IN ({placeholders})",
                (current, *ids),
            )
    return [command_dict(row) for row in rows]


@app.post("/api/commands")
def create_command(payload: CommandCreateRequest) -> dict[str, Any]:
    if payload.command not in SAFE_COMMANDS:
        raise HTTPException(status_code=400, detail="Unsupported safe command")
    current = now()
    with connect() as conn:
        cursor = conn.execute(
            """
            INSERT INTO commands (computer_id, command, payload, status, created_at)
            VALUES (?, ?, ?, 'queued', ?)
            """,
            (payload.computer_id, payload.command, encode_json(payload.payload), current),
        )
        command_id = cursor.lastrowid
    return {"ok": True, "id": command_id}


@app.post("/api/commands/{command_id}/result")
def command_result(
    command_id: int,
    payload: CommandResultRequest,
    _: str = Depends(require_bearer),
) -> dict[str, Any]:
    with connect() as conn:
        result = conn.execute(
            """
            UPDATE commands
            SET status = ?, result = ?, error = ?, completed_at = ?
            WHERE id = ?
            """,
            (
                payload.status,
                encode_json(payload.result),
                payload.error,
                now(),
                command_id,
            ),
        )
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="Command not found")
    return {"ok": True}


@app.get("/api/packages")
def packages() -> list[dict[str, Any]]:
    seed_packages()
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM packages ORDER BY name ASC, version DESC"
        ).fetchall()
    return [package_dict(row) for row in rows]


@app.get("/api/packages/{name}")
def package(name: str) -> dict[str, Any]:
    seed_packages()
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM packages WHERE name = ? ORDER BY version DESC",
            (name,),
        ).fetchall()
    if not rows:
        raise HTTPException(status_code=404, detail="Package not found")
    return {"name": name, "versions": [package_dict(row) for row in rows]}


@app.get("/api/packages/{name}/{version}/manifest")
def package_manifest(name: str, version: str) -> dict[str, Any]:
    seed_packages()
    with connect() as conn:
        if version == "latest":
            row = latest_package_row(conn, name)
        else:
            row = conn.execute(
                "SELECT * FROM packages WHERE name = ? AND version = ?",
                (name, version),
            ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Package version not found")
    return decode_json(row["manifest"], {})


@app.get("/packages/{name}/{version}/{file_path:path}")
def package_file(name: str, version: str, file_path: str) -> FileResponse:
    base = (PACKAGES_DIR / name / version).resolve()
    candidate = (base / file_path).resolve()
    if base not in candidate.parents and candidate != base:
        raise HTTPException(status_code=400, detail="Invalid package path")
    if not candidate.is_file():
        raise HTTPException(status_code=404, detail="Package file not found")
    return FileResponse(candidate)


@app.get("/api/alerts")
def alerts(include_resolved: bool = False) -> list[dict[str, Any]]:
    query = "SELECT * FROM alerts"
    params: tuple[Any, ...] = ()
    if not include_resolved:
        query += " WHERE resolved = 0"
    query += " ORDER BY created_at DESC"
    with connect() as conn:
        rows = conn.execute(query, params).fetchall()
    return [dict(row) for row in rows]


@app.post("/api/alerts/{alert_id}/resolve")
def resolve_alert(alert_id: int) -> dict[str, Any]:
    with connect() as conn:
        result = conn.execute(
            "UPDATE alerts SET resolved = 1, resolved_at = ? WHERE id = ?",
            (now(), alert_id),
        )
        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="Alert not found")
    return {"ok": True}
