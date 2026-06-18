# RIG Platform

RIG is becoming a CC:Tweaked developer platform.

The long-term platform has three systems:

- **RIG** - developer API, package tooling, SDKs, hub services, and package registry.
- **Dock** - OS layer for Pocket Computers and Advanced Computers.
- **Luma** - in-game internet layer with browser, domains, search, and site builder.

Repositories:

- `R15ofc/cc-rig` - RIG core and hub.
- `R15ofc/cc-dock` - DockOS.
- `R15ofc/cc-luma` - Luma Browser.

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

RIG is the developer API/tooling layer. It does not need hub registration for the basic DockOS + App Store flow.

```lua
wget https://raw.githubusercontent.com/R15ofc/cc-rig/main/rig-installer.lua rig-installer.lua
rig-installer.lua --source https://raw.githubusercontent.com/R15ofc/cc-rig/main/cc
rig os install dock
dock
```

Use Dock Store inside the Dock UI for apps. The store can use a CC rednet server when present and falls back to the built-in verified catalog when offline.

After the first install, update RIG with `rig update`.

## RIG Hub Server Install

```sh
mkdir -p ~/cc-rig-server
cd ~/cc-rig-server
curl -fsSLO https://raw.githubusercontent.com/R15ofc/cc-rig/main/server/install-rig-server.sh
curl -fsSLO https://raw.githubusercontent.com/R15ofc/cc-rig/main/server/startup-rig-hub.sh
chmod +x install-rig-server.sh startup-rig-hub.sh
./install-rig-server.sh
./startup-rig-hub.sh
```

Current LAN URL for this machine:

```text
http://192.168.31.21:8000
```

Hub registration is optional and only needed for hosted registry/device APIs:

```lua
rig hub set http://192.168.31.21:8000
rig register http://192.168.31.21:8000 <token>
```

## CC Server PC

Use this on an in-game CC PC with a modem for Dock Store and basic Luma pages:

```lua
wget https://raw.githubusercontent.com/R15ofc/cc-dock/main/dock-installer.lua dock-installer.lua
dock-installer.lua --source https://raw.githubusercontent.com/R15ofc/cc-dock/main/cc
dock-server startup install
dock-server
```

## Luma Internet Gateway

Use this on a real PC/Mac/Linux host when Luma should fetch normal HTTP/HTTPS pages through one local URL:

```sh
mkdir -p ~/cc-luma-gateway
cd ~/cc-luma-gateway
curl -fsSLO https://raw.githubusercontent.com/R15ofc/cc-luma/main/server/luma-gateway.py
curl -fsSLO https://raw.githubusercontent.com/R15ofc/cc-luma/main/server/startup-luma-gateway.sh
chmod +x luma-gateway.py startup-luma-gateway.sh
./startup-luma-gateway.sh
```

Then on CC:

```lua
luma gateway set http://192.168.31.21:9000
```

## Current Direction

RIG should move from monitoring-first toward developer tooling:

- package upload from GitHub/gist;
- package verification status;
- warnings for unreviewed packages;
- hub-side package removal/blocking;
- Dock app store integration;
- Luma publishing and discovery.

`secret/` is ignored by git so local tokens do not get committed.
