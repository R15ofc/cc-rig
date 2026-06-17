dofile("/rig/bootstrap.lua")

local httpc = dofile("/rig/bootstrap.lua").require("http")
local logger = dofile("/rig/bootstrap.lua").require("logger")
local packages = dofile("/rig/bootstrap.lua").require("package")
local process = dofile("/rig/bootstrap.lua").require("process")
local security = dofile("/rig/bootstrap.lua").require("security")
local telemetry = dofile("/rig/bootstrap.lua").require("telemetry")

local VERSION = "0.1.0"
local STOP_FILE = "/rig/agent.stop"

local function computer_id()
  return os.getComputerID()
end

local function label()
  if os.getComputerLabel then
    return os.getComputerLabel()
  end
  return nil
end

local function register_device(identity)
  if not identity or not identity.hub_url or not identity.token then
    return nil, "identity is missing hub URL or token"
  end
  identity.computer_id = identity.computer_id or computer_id()
  local body = {
    computer_id = identity.computer_id,
    label = label(),
    device_type = security.device_type(),
    agent_version = VERSION,
    token = identity.token,
  }
  local result, err = httpc.post(httpc.join(identity.hub_url, "/api/register"), body)
  if not result then
    return nil, err
  end
  identity.registered = true
  identity.agent_version = VERSION
  identity.label = body.label
  identity.device_type = body.device_type
  security.save_identity(identity)
  return true
end

local function heartbeat(identity)
  return httpc.post(httpc.join(identity.hub_url, "/api/heartbeat"), {
    computer_id = identity.computer_id or computer_id(),
    uptime = os.clock(),
    status = "online",
    agent_version = VERSION,
  }, identity.token)
end

local function send_telemetry(identity)
  return httpc.post(httpc.join(identity.hub_url, "/api/telemetry"), {
    computer_id = identity.computer_id or computer_id(),
    data = telemetry.collect(),
  }, identity.token)
end

local function send_logs(identity, entries)
  return httpc.post(httpc.join(identity.hub_url, "/api/logs"), {
    computer_id = identity.computer_id or computer_id(),
    entries = entries or logger.read(100),
  }, identity.token)
end

local function post_result(identity, command_id, status, result, err)
  return httpc.post(httpc.join(identity.hub_url, "/api/commands/" .. tostring(command_id) .. "/result"), {
    computer_id = identity.computer_id or computer_id(),
    status = status,
    result = result or {},
    error = err,
  }, identity.token)
end

local function command_arg(payload, ...)
  payload = payload or {}
  for _, key in ipairs({ ... }) do
    if payload[key] ~= nil and payload[key] ~= "" then
      return payload[key]
    end
  end
  return nil
end

local function execute_command(identity, command)
  local payload = command.payload or {}
  local name = command.command

  if name == "ping" then
    return true, { message = "pong", uptime = os.clock() }
  end

  if name == "reboot" then
    return true, { rebooting = true }, "reboot"
  end

  if name == "shutdown" then
    return true, { shutting_down = true }, "shutdown"
  end

  if name == "install" then
    local package_name = command_arg(payload, "package", "name")
    local ok, result = packages.install(package_name, payload.version or "latest")
    return ok ~= nil, ok and { package = result.name, version = result.version } or nil, nil, result
  end

  if name == "remove" then
    local package_name = command_arg(payload, "package", "name")
    local ok, err = packages.remove(package_name)
    return ok ~= nil, { package = package_name }, nil, err
  end

  if name == "upgrade" then
    local package_name = command_arg(payload, "package", "name")
    local ok, result = packages.upgrade(package_name)
    return ok ~= nil, type(result) == "table" and result or { upgraded = package_name or "all" }, nil, result
  end

  if name == "start_app" then
    local app = command_arg(payload, "app", "name")
    local path = payload.path or ("/bin/" .. tostring(app) .. ".lua")
    local ok, result = process.start(app, path, payload.args or {})
    return ok ~= nil, result, nil, result
  end

  if name == "stop_app" then
    local app = command_arg(payload, "app", "name")
    local ok, result = process.stop(app)
    return ok ~= nil, result, nil, result
  end

  if name == "restart_app" then
    local app = command_arg(payload, "app", "name")
    local ok, result = process.restart(app)
    return ok ~= nil, result, nil, result
  end

  if name == "set_label" then
    local new_label = command_arg(payload, "label")
    if os.setComputerLabel then
      os.setComputerLabel(new_label)
    end
    identity.label = new_label
    security.save_identity(identity)
    register_device(identity)
    return true, { label = new_label }
  end

  if name == "send_log" then
    local entries = logger.read(payload.limit or 100)
    local ok, err = send_logs(identity, entries)
    return ok ~= nil, { count = #entries }, nil, err
  end

  return false, nil, nil, "unsupported command"
end

local function poll_commands(identity)
  local url = httpc.join(identity.hub_url, "/api/commands/poll?computer_id=" .. tostring(identity.computer_id or computer_id()))
  local commands, err = httpc.get(url, identity.token)
  if not commands then
    return nil, err
  end
  for _, command in ipairs(commands) do
    local ok, result, action, command_err = execute_command(identity, command)
    if ok then
      post_result(identity, command.id, "done", result or {})
      if action == "reboot" then
        sleep(0.5)
        os.reboot()
      elseif action == "shutdown" then
        sleep(0.5)
        os.shutdown()
      end
    else
      post_result(identity, command.id, "error", {}, tostring(command_err or "command failed"))
    end
  end
  return true
end

logger.info("agent", "RIG agent started")

local last_heartbeat = -10
local last_telemetry = -10
local last_commands = -10
local last_register = -30

while true do
  if fs.exists(STOP_FILE) then
    fs.delete(STOP_FILE)
    logger.info("agent", "RIG agent stopped")
    return
  end

  local identity = security.load_identity()
  if identity and identity.hub_url and identity.token then
    identity.computer_id = identity.computer_id or computer_id()
    local current = os.clock()

    if not identity.registered and current - last_register >= 30 then
      local ok, err = register_device(identity)
      if not ok then
        logger.warn("agent", "Registration failed: " .. tostring(err))
      end
      last_register = current
    end

    if current - last_heartbeat >= 5 then
      local ok, err = heartbeat(identity)
      if not ok then
        logger.warn("agent", "Heartbeat failed: " .. tostring(err))
      end
      last_heartbeat = current
    end

    if current - last_telemetry >= 10 then
      local ok, err = send_telemetry(identity)
      if not ok then
        logger.warn("agent", "Telemetry failed: " .. tostring(err))
      end
      last_telemetry = current
    end

    if current - last_commands >= 2 then
      local ok, err = poll_commands(identity)
      if not ok then
        logger.warn("agent", "Command poll failed: " .. tostring(err))
      end
      last_commands = current
    end
  else
    logger.warn("agent", "Identity is missing; run rig register")
    sleep(10)
  end

  sleep(1)
end
