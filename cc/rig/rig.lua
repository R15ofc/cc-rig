local function add_rig_package_paths()
  if not package or type(package.path) ~= "string" then
    return
  end
  for _, pattern in ipairs({ "/?.lua", "/?/init.lua" }) do
    if not package.path:find(pattern, 1, true) then
      package.path = package.path .. ";" .. pattern
    end
  end
end

add_rig_package_paths()

local fsx = require("rig.lib.fsx")
local httpc = require("rig.lib.http")
local json = require("rig.lib.json")
local logger = require("rig.lib.logger")
local packages = require("rig.lib.package")
local peripheral_info = require("rig.lib.peripheral")
local rednet_info = require("rig.lib.rednet")
local security = require("rig.lib.security")
local telemetry = require("rig.lib.telemetry")
local ui = require("rig.lib.ui")
local updater = require("rig.lib.updater")

local VERSION = "0.1.0"

local args = { ... }
local PROGRESS_FRAMES = { "/", "-", "\\", "|" }
local progress_line = nil
local progress_frame = 1

local function print_help()
  print("RIG " .. VERSION)
  print("Usage: rig <command> [args]")
  print("")
  print("Core:")
  print("  rig help")
  print("  rig version")
  print("  rig doctor")
  print("  rig register <hub_url> <token>")
  print("  rig status")
  print("  rig startup install")
  print("")
  print("Agent:")
  print("  rig agent start")
  print("  rig agent stop")
  print("  rig update [source_url]")
  print("")
  print("Packages:")
  print("  rig search <query>")
  print("  rig info <package>")
  print("  rig install <package>")
  print("  rig remove <package>")
  print("  rig list")
  print("  rig upgrade [package]")
  print("")
  print("Diagnostics:")
  print("  rig logs")
  print("  rig telemetry")
  print("  rig peripherals")
  print("  rig gps")
  print("")
  print("Gateway:")
  print("  rig gateway start")
  print("  rig gateway status")
end

local function require_arg(index, name)
  if args[index] == nil or args[index] == "" then
    ui.fail(name .. " is required")
    return nil
  end
  return args[index]
end

local function terminal_width()
  if term and term.getSize then
    local width = term.getSize()
    return width or 51
  end
  return 51
end

local function fit_line(text)
  local width = terminal_width()
  text = tostring(text or "")
  if #text <= width then
    return text
  end
  if width <= 3 then
    return text:sub(1, width)
  end
  return text:sub(1, width - 3) .. "..."
end

local function short_name(path)
  path = tostring(path or "")
  return path:match("[^/]+$") or path
end

local function next_frame()
  local frame = PROGRESS_FRAMES[progress_frame]
  progress_frame = progress_frame + 1
  if progress_frame > #PROGRESS_FRAMES then
    progress_frame = 1
  end
  return frame
end

local function progress_text(stage, done, total, label, frame)
  local width = 12
  local percent = 0
  if total > 0 then
    percent = (done / total) * 100
  end
  local filled = math.floor((percent / 100) * width + 0.5)
  if filled < 0 then
    filled = 0
  elseif filled > width then
    filled = width
  end
  return string.format(
    "RIG %s [%s%s] %6.2f%% %s %s",
    frame or " ",
    string.rep("#", filled),
    string.rep("-", width - filled),
    percent,
    stage,
    short_name(label)
  )
end

local function write_progress(text)
  if term and term.getCursorPos and term.setCursorPos and term.clearLine and term.write then
    local _, current_y = term.getCursorPos()
    progress_line = progress_line or current_y
    term.setCursorPos(1, progress_line)
    term.clearLine()
    term.write(fit_line(text))
  end
end

local function finish_progress(text)
  if term and term.getCursorPos and term.setCursorPos then
    write_progress(text)
    local _, current_y = term.getCursorPos()
    term.setCursorPos(1, current_y + 1)
    progress_line = nil
  else
    print(text)
  end
end

local function start_agent()
  fsx.delete("/rig/agent.stop")
  if not fs.exists("/rig/agent.lua") then
    return nil, "/rig/agent.lua not found"
  end
  if not multishell then
    return nil, "multishell is unavailable"
  end
  local tab = multishell.launch({}, "/rig/agent.lua")
  if tab and multishell.setTitle then
    multishell.setTitle(tab, "RIG Agent")
  end
  return true, tab
end

local function install_startup()
  local ok, err = updater.install_startup()
  if not ok then
    ui.fail("Startup hook failed: " .. tostring(err))
    return
  end
  local config = security.load_config()
  config.agent_enabled = true
  security.save_config(config)
  ui.ok("Startup hook installed")
  local ok, result = start_agent()
  if ok then
    ui.ok("Agent started in tab " .. tostring(result))
  else
    ui.fail("Startup installed, but agent was not started: " .. tostring(result))
  end
end

local function register()
  local hub_url = require_arg(2, "hub_url")
  local token = require_arg(3, "token")
  if not hub_url or not token then
    return
  end
  hub_url = hub_url:gsub("/+$", "")
  local identity = {
    hub_url = hub_url,
    token = token,
    computer_id = os.getComputerID(),
    label = os.getComputerLabel and os.getComputerLabel() or nil,
    device_type = security.device_type(),
    agent_version = VERSION,
    registered = false,
  }
  local result, err = httpc.post(httpc.join(hub_url, "/api/register"), {
    computer_id = identity.computer_id,
    label = identity.label,
    device_type = identity.device_type,
    agent_version = VERSION,
    token = token,
  })
  if not result then
    ui.fail("Registration failed: " .. tostring(err))
    return
  end
  identity.registered = true
  security.save_identity(identity)
  local config = security.load_config()
  config.agent_enabled = true
  security.save_config(config)
  ui.ok("Registered computer " .. tostring(identity.computer_id))
end

local function status()
  local identity = security.load_identity()
  if not identity then
    ui.fail("Device is not registered")
    return
  end
  ui.print_kv("Computer ID", identity.computer_id or os.getComputerID())
  ui.print_kv("Hub URL", identity.hub_url)
  ui.print_kv("Device type", identity.device_type or security.device_type())
  ui.print_kv("Registered", tostring(identity.registered == true))
  ui.print_kv("Agent enabled", tostring(security.load_config().agent_enabled ~= false))
end

local function doctor()
  ui.print_kv("HTTP API", http and "enabled" or "disabled")
  ui.print_kv("Multishell", multishell and "available" or "unavailable")
  ui.print_kv("Identity", fs.exists(security.IDENTITY_PATH) and "present" or "missing")
  ui.print_kv("Startup hook", fs.exists("/startup/rig.lua") and "installed" or "missing")
  ui.print_kv("Root startup", fs.exists("/startup.lua") and "present" or "missing")
end

local function print_packages()
  local installed = packages.list()
  local count = 0
  for name, item in pairs(installed) do
    print(name .. " " .. tostring(item.version))
    count = count + 1
  end
  if count == 0 then
    print("No packages installed.")
  end
end

local function print_search()
  local query = table.concat(args, " ", 2)
  local result, err = packages.search(query)
  if not result then
    ui.fail(err)
    return
  end
  for _, pkg in ipairs(result) do
    print(pkg.name .. " " .. pkg.version .. " - " .. tostring(pkg.description or ""))
  end
end

local function print_info()
  local name = require_arg(2, "package")
  if not name then
    return
  end
  local result, err = packages.info(name)
  if not result then
    ui.fail(err)
    return
  end
  print(json.encode(result))
end

local function install_package()
  local name = require_arg(2, "package")
  if not name then
    return
  end
  local ok, result = packages.install(name, args[3] or "latest")
  if not ok then
    ui.fail(result)
    return
  end
  ui.ok("Installed " .. result.name .. " " .. result.version)
end

local function remove_package()
  local name = require_arg(2, "package")
  if not name then
    return
  end
  local ok, err = packages.remove(name)
  if not ok then
    ui.fail(err)
    return
  end
  ui.ok("Removed " .. name)
end

local function upgrade_package()
  local ok, result = packages.upgrade(args[2])
  if not ok then
    ui.fail(result)
    return
  end
  ui.ok("Upgrade complete")
end

local function update_core()
  local source_url = (args[2] and args[2] ~= "") and args[2] or updater.DEFAULT_SOURCE_URL
  local active_stage = nil
  print("RIG Core Update")
  print("Source: " .. source_url)
  local ok, result = updater.update(source_url, function(stage, done, total, label)
    if stage ~= active_stage then
      if active_stage == "download" then
        finish_progress(progress_text("download", total, total, "complete", " "))
      elseif active_stage == "apply" then
        finish_progress(progress_text("apply", total, total, "complete", " "))
      end
      active_stage = stage
      if stage == "download" then
        print("==> Downloading core files")
      elseif stage == "apply" then
        print("==> Applying files")
      end
    end
    if stage == "complete" then
      finish_progress(progress_text("complete", total, total, label, " "))
    elseif stage == "download" or stage == "apply" then
      write_progress(progress_text(stage, done, total, label, next_frame()))
    end
  end)
  if not ok then
    ui.fail(result)
    return
  end
  ui.ok("RIG core update complete")
  ui.ok("Files updated: " .. tostring(result.count))
  print("Restart the agent to run the updated code.")
end

local function print_logs()
  local entries = logger.read(100)
  for _, entry in ipairs(entries) do
    print("[" .. tostring(entry.ts) .. "] " .. tostring(entry.level) .. " " .. tostring(entry.app) .. ": " .. tostring(entry.message))
  end
  if #entries == 0 then
    print("No logs.")
  end
end

local function print_telemetry()
  print(json.encode(telemetry.collect()))
end

local function print_peripherals()
  local list = peripheral_info.list()
  for _, item in ipairs(list) do
    print(item.name .. " " .. item.type)
  end
  if #list == 0 then
    print("No peripherals.")
  end
end

local function print_gps()
  if not gps or not gps.locate then
    ui.fail("GPS API is unavailable")
    return
  end
  local x, y, z = gps.locate(2)
  if not x then
    ui.fail("GPS position not found")
    return
  end
  print(tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z))
end

local function gateway(command)
  if command == "start" then
    if not multishell then
      ui.fail("multishell is unavailable")
      return
    end
    local tab = multishell.launch({}, "/rig/gateway.lua")
    if tab and multishell.setTitle then
      multishell.setTitle(tab, "RIG Gateway")
    end
    ui.ok("Gateway started in tab " .. tostring(tab))
  elseif command == "status" then
    local status_map = rednet_info.status()
    local count = 0
    for modem, open in pairs(status_map) do
      print(modem .. ": " .. tostring(open))
      count = count + 1
    end
    if count == 0 then
      print("No rednet modems found.")
    end
  else
    ui.fail("Unknown gateway command")
  end
end

local command = args[1] or "help"

if command == "help" then
  print_help()
elseif command == "version" then
  print(VERSION)
elseif command == "doctor" then
  doctor()
elseif command == "register" then
  register()
elseif command == "status" then
  status()
elseif command == "startup" and args[2] == "install" then
  install_startup()
elseif command == "install-startup" then
  install_startup()
elseif command == "agent" and args[2] == "start" then
  local ok, result = start_agent()
  if ok then
    ui.ok("Agent started in tab " .. tostring(result))
  else
    ui.fail(result)
  end
elseif command == "agent" and args[2] == "stop" then
  fsx.write_file("/rig/agent.stop", "stop")
  ui.ok("Stop requested")
elseif command == "update" then
  update_core()
elseif command == "search" then
  print_search()
elseif command == "info" then
  print_info()
elseif command == "install" then
  install_package()
elseif command == "remove" then
  remove_package()
elseif command == "list" then
  print_packages()
elseif command == "upgrade" then
  upgrade_package()
elseif command == "logs" then
  print_logs()
elseif command == "telemetry" then
  print_telemetry()
elseif command == "peripherals" then
  print_peripherals()
elseif command == "gps" then
  print_gps()
elseif command == "gateway" then
  gateway(args[2])
else
  ui.fail("Unknown command: " .. tostring(command))
  print_help()
end
