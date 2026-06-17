dofile("/rig/bootstrap.lua")

local httpc = dofile("/rig/bootstrap.lua").require("http")
local logger = dofile("/rig/bootstrap.lua").require("logger")
local rednet_lib = dofile("/rig/bootstrap.lua").require("rednet")
local security = dofile("/rig/bootstrap.lua").require("security")

local identity = security.load_identity()
if not identity or not identity.hub_url or not identity.token then
  print("Gateway requires a registered RIG identity.")
  return
end

local opened = rednet_lib.open_all()
if #opened == 0 then
  print("No rednet modem is available.")
else
  print("Opened rednet on: " .. table.concat(opened, ", "))
end

if rednet and rednet.host then
  pcall(rednet.host, "rig.gateway", tostring(identity.computer_id or os.getComputerID()))
end

logger.info("gateway", "RIG gateway started")

local function forward_telemetry(message)
  if not security.validate_rednet(message, identity.token) then
    return false, "invalid rednet token signature"
  end
  return httpc.post(httpc.join(identity.hub_url, "/api/telemetry"), {
    computer_id = message.computer_id,
    data = message.data or {},
  }, identity.token)
end

local function poll_and_broadcast()
  local url = httpc.join(identity.hub_url, "/api/commands/poll?computer_id=" .. tostring(identity.computer_id or os.getComputerID()))
  local commands = httpc.get(url, identity.token)
  if type(commands) ~= "table" or not rednet then
    return
  end
  for _, command in ipairs(commands) do
    local payload = command.payload or {}
    if payload.target_rednet then
      local nonce = os.clock()
      rednet.broadcast({
        computer_id = identity.computer_id or os.getComputerID(),
        command = command.command,
        payload = payload,
        nonce = nonce,
        token_signature = security.rednet_signature(identity.token, nonce),
      }, "rig.gateway.command")
    end
  end
end

while true do
  if rednet then
    local sender, message, protocol = rednet.receive(nil, 2)
    if sender and protocol == "rig.telemetry" then
      local ok, err = forward_telemetry(message)
      if not ok then
        logger.warn("gateway", "Telemetry forward failed: " .. tostring(err))
      end
    end
  else
    sleep(2)
  end
  poll_and_broadcast()
end
