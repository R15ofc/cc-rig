# RIG - Runtime Infrastructure Grid

RIG is a CC:Tweaked ecosystem with a FastAPI hub, a static fleet dashboard, and pure Lua client code for ComputerCraft devices.

## Layout

- `rig-hub/` - Python 3.12 FastAPI server with SQLite, package registry, dashboard, and Docker files.
- `cc/` - CC:Tweaked Lua runtime files intended to be copied to a computer's root filesystem.
- `goal.md` - Original project specification.

## Quick Start

```sh
cd rig-hub
python3.12 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000` for the dashboard.

On a CC:Tweaked computer, install the client with the standalone installer:

```lua
wget https://raw.githubusercontent.com/R15ofc/cc-rig/main/rig-installer.lua rig-installer.lua
rig-installer.lua http://127.0.0.1:8000 your-token
```

After the first install, update the CC client with `rig update`.

`secret/` is ignored by git so local tokens do not get committed.
