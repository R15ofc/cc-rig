# RIG Hub

RIG Hub is a Python 3.12 FastAPI server for CC:Tweaked device registration, heartbeats, telemetry, logs, queued commands, package registry data, alerts, and a static dashboard.

## Local Setup

```sh
python3.12 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

The dashboard is served at `http://127.0.0.1:8000`.

## Docker

```sh
docker compose up --build
```

SQLite data is stored in `./data/rig.db` when running with Docker Compose.

## API Token Model

Devices register with a token. The server stores only a SHA-256 token hash in SQLite and expects clients to send the same token in:

```http
Authorization: Bearer <token>
```

This is token authentication, not encryption.

