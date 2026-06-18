# RIG Dev API

RIG is the developer API layer for building real CC:Tweaked systems:

- **DockOS** - Advanced Computer OS shell, windows, app store, apps.
- **Luma** - in-game browser, Luma pages, search, and HTTP gateway.
- **RIG devapi** - reusable APIs for UI, apps, networking, stores, and runtime helpers.

RIG is not hub-first. A hub can exist later as optional infrastructure, but the base system works from raw GitHub files, CC rednet servers, and the Luma gateway.

## Install RIG

Run on a CC:Tweaked Advanced Computer:

```lua
wget https://raw.githubusercontent.com/R15ofc/cc-rig/main/rig-installer.lua rig-installer.lua
rig-installer.lua --source https://raw.githubusercontent.com/R15ofc/cc-rig/main/cc
rig api
```

## Install the OS UI

```lua
rig os install dock
dock
```

Dock uses the RIG devapi when present and falls back safely when installed directly.

## RIG devapi

Installed modules:

- `/rig/devapi/ui.lua` - Advanced PC UI primitives: topbars, cards, buttons, modals, hitboxes.
- `/rig/devapi/app.lua` - app install/run helpers, hidden installer execution, file helpers.
- `/rig/devapi/net.lua` - Luma gateway, HTTP JSON, rednet request helpers.
- `/rig/devapi/store.lua` - local/offline catalog and trust labels.

CLI:

```lua
rig api
rig doctor
rig update
rig os install dock
```

## CC Server PC

Use this on an in-game CC PC with a modem for Dock Store and Luma pages:

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

## Legacy Optional Hub

`rig-hub/` and `server/` are still present for future registry/admin experiments, but they are not required for RIG, DockOS, or Luma.

Current local RIG Hub URL if you intentionally run it:

```text
http://192.168.31.21:8000
```
