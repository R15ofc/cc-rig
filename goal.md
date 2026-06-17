Build a project called RIG — Runtime Infrastructure Grid.

RIG is a CC:Tweaked ecosystem similar to Homebrew + fleet monitoring + remote control.

Create a monorepo with two main parts:

1. rig-hub/
A Python 3.12 FastAPI server with SQLite.
It must provide:
- Device registration
- Heartbeat API
- Telemetry API
- Logs API
- Command queue API
- Package registry API
- Static dashboard UI
- Package file serving
- SQLite persistence
- Dockerfile
- docker-compose.yml
- README with setup instructions

2. cc/
Pure Lua code for CC:Tweaked.
It must provide:
- /rig/rig.lua main CLI
- /rig/agent.lua background agent
- /bin/rig.lua launcher
- /startup/rig.lua startup hook
- /rig/lib/http.lua
- /rig/lib/json.lua
- /rig/lib/fsx.lua
- /rig/lib/logger.lua
- /rig/lib/security.lua
- /rig/lib/telemetry.lua
- /rig/lib/package.lua
- /rig/lib/process.lua
- /rig/lib/peripheral.lua
- /rig/lib/rednet.lua
- /rig/lib/ui.lua

Use no external Lua dependencies. Use CC:Tweaked APIs only.

Important code style:
- No Russian comments in code.
- Console output must be English.
- Keep Lua files simple and readable.
- Avoid overengineering.
- Dangerous remote Lua execution must be disabled by default.
- Do not use real encryption claims. Use API tokens and token hashes on the server.
- Store the CC device identity in /rig/identity.sec.
- Store installed packages in /rig/lock.lua.
- Store logs in /rig/logs/.
- Use JSON for HTTP communication via textutils.serializeJSON and textutils.unserializeJSON.

Server requirements:

Use FastAPI and SQLite.

Create these API routes:

GET /health

POST /api/register
Request:
{
  "computer_id": number,
  "label": string | null,
  "device_type": string,
  "agent_version": string,
  "token": string
}

POST /api/heartbeat
Request:
{
  "computer_id": number,
  "uptime": number,
  "status": string,
  "agent_version": string
}

POST /api/telemetry
Request:
{
  "computer_id": number,
  "data": object
}

POST /api/logs
Request:
{
  "computer_id": number,
  "entries": [
    {
      "ts": number,
      "level": string,
      "app": string,
      "message": string
    }
  ]
}

GET /api/devices
GET /api/devices/{computer_id}
GET /api/devices/{computer_id}/telemetry
GET /api/devices/{computer_id}/logs

GET /api/commands/poll?computer_id=123
POST /api/commands
POST /api/commands/{command_id}/result

GET /api/packages
GET /api/packages/{name}
GET /api/packages/{name}/{version}/manifest
GET /packages/{name}/{version}/{file_path:path}

GET /api/alerts
POST /api/alerts/{alert_id}/resolve

Database tables:
- devices
- telemetry
- logs
- commands
- packages
- installs
- alerts
- api_keys

Dashboard requirements:
Create a simple static HTML/CSS/JS dashboard served by FastAPI.
Pages/sections:
- Overview
- Devices
- Device details
- Logs
- Commands
- Packages
- Alerts

Dashboard must show:
- Online/offline devices
- Last seen
- Computer ID
- Label
- Device type
- Agent version
- Latest telemetry JSON
- Logs
- Alerts
- Buttons to send commands:
  - ping
  - reboot
  - install package
  - upgrade package
  - start app
  - stop app
  - restart app

CC Lua requirements:

rig CLI commands:
- rig help
- rig version
- rig doctor
- rig register <hub_url> <token>
- rig status
- rig agent start
- rig agent stop
- rig update
- rig search <query>
- rig info <package>
- rig install <package>
- rig remove <package>
- rig list
- rig upgrade
- rig logs
- rig telemetry
- rig peripherals
- rig gps
- rig gateway start
- rig gateway status

RigAgent:
- Loads /rig/identity.sec
- Registers device if needed
- Sends heartbeat every 5 seconds
- Sends telemetry every 10 seconds
- Polls commands every 2 seconds
- Executes safe commands:
  - ping
  - reboot
  - shutdown
  - install
  - remove
  - upgrade
  - start_app
  - stop_app
  - restart_app
  - set_label
  - send_log
- Sends command results back to server
- Writes local logs
- Survives API errors and retries later
- Never crashes on missing peripherals

Telemetry collector:
Collect:
- computer_id
- computer_label
- uptime
- CraftOS version
- disk free/capacity if available
- shell path if shell API exists
- GPS position using gps.locate with a short timeout
- peripheral list using peripheral.getNames and peripheral.getType
- rednet open status if possible
- inventory summaries for attached inventory peripherals
- energy storage summaries using getEnergy and getEnergyCapacity when available
- fluid storage summaries using tanks when available
- turtle fuel and inventory when turtle API exists
- redstone input states if available
- installed package list from lock file
- running app states from process manager

Package manager:
- Download registry from RIG Hub
- Install files from package manifest
- Create /bin launchers for bin entries
- Save installed packages in /rig/lock.lua
- Remove installed files on uninstall
- Support dependencies in simple recursive order
- Support latest version resolution
- Validate that paths never escape allowed directories

Startup:
- /startup/rig.lua should add /bin to shell path if shell exists
- It should start /rig/agent.lua in the background if enabled in config
- It should not break normal shell startup

Create example packages:
1. logger
2. hello
3. roadrover-placeholder
4. gateway-placeholder

RIG Gateway:
Create a Lua gateway placeholder which:
- Opens rednet on all attached modems
- Hosts protocol "rig.gateway"
- Receives rednet messages with protocol "rig.telemetry"
- Forwards them to RIG Hub over HTTP
- Polls server commands and broadcasts them to target rednet computers
- Uses simple shared token validation

Security:
- Server stores token hashes, not plain tokens
- CC client sends token in Authorization header: Bearer <token>
- Rednet messages include computer_id, nonce, token_signature placeholder
- Document clearly that rednet is not secure on untrusted multiplayer servers
- Dangerous exec command must be disabled unless config explicitly enables it

Local development:
- Provide docker-compose.yml for RIG Hub
- Server runs on port 8080
- README explains:
  - how to start server
  - how to enable CC:Tweaked HTTP access to local server
  - how to install bootstrap on a CC computer
  - how to register a device
  - how to view dashboard
  - how to add a package

Deliver working code, not only skeletons.
All routes should run.
The dashboard should actually load data.
The CC CLI should have real command handling.
The agent should actually send heartbeat/telemetry/poll commands.