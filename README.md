# RIG - Runtime Infrastructure Grid

RIG is a CC:Tweaked ecosystem with a FastAPI hub, a static fleet dashboard, and pure Lua client code for ComputerCraft devices.

## Layout

- `rig-hub/` - Python 3.12 FastAPI server with SQLite, package registry, dashboard, and Docker files.
- `cc/` - CC:Tweaked Lua runtime files intended to be copied to a computer's root filesystem.
- `task.md` - Original project specification.

## Quick Start

```sh
cd rig-hub
python3.12 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000` for the dashboard.

On a CC:Tweaked computer, copy the contents of `cc/` to the root filesystem, then run:

```lua
/bin/rig.lua register http://127.0.0.1:8000 your-token
/bin/rig.lua startup install
/bin/rig.lua agent start
```

`secret/` is ignored by git so local tokens do not get committed.
