# RIG Platform

RIG is becoming a CC:Tweaked developer platform.

The long-term platform has three systems:

- **RIG** - developer API, package tooling, SDKs, hub services, and package registry.
- **Dock** - OS layer for Pocket Computers and Advanced Computers.
- **Luma** - in-game internet layer with browser, domains, search, and site builder.

The current server/client code remains in this repository as the foundation.

## Layout

- `rig-hub/` - Python 3.12 FastAPI server with SQLite, package registry, dashboard, and Docker files.
- `cc/` - CC:Tweaked Lua runtime files intended to be copied to a computer's root filesystem.
- `systems/` - planned RIG, Dock, Luma, and shared platform specs.
- `docs/` - roadmap and package trust policy.
- `PLATFORM.md` - product direction and trust model.
- `goal.md` - Original project specification.

## Hub Quick Start

```sh
cd rig-hub
python3.12 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000` for the dashboard.

## CC Client Install

```lua
wget https://raw.githubusercontent.com/R15ofc/cc-rig/main/rig-installer.lua rig-installer.lua
rig-installer.lua --source https://raw.githubusercontent.com/R15ofc/cc-rig/main/cc http://<hub-ip>:8000 your-token
```

After the first install, update the CC client with `rig update`.

## Current Direction

RIG should move from monitoring-first toward developer tooling:

- package upload from GitHub/gist;
- package verification status;
- warnings for unreviewed packages;
- hub-side package removal/blocking;
- Dock app store integration;
- Luma publishing and discovery.

`secret/` is ignored by git so local tokens do not get committed.
