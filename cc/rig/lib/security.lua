local fsx = require("rig.lib.fsx")

local M = {}
M.IDENTITY_PATH = "/rig/identity.sec"
M.CONFIG_PATH = "/rig/config.lua"

function M.load_identity()
  return fsx.load_table(M.IDENTITY_PATH, nil)
end

function M.save_identity(identity)
  identity = identity or {}
  return fsx.save_table(M.IDENTITY_PATH, identity)
end

function M.load_config()
  local config = fsx.load_table(M.CONFIG_PATH, {})
  if config.agent_enabled == nil then
    config.agent_enabled = true
  end
  return config
end

function M.save_config(config)
  return fsx.save_table(M.CONFIG_PATH, config or {})
end

function M.device_type()
  if turtle then
    return "turtle"
  end
  if pocket then
    return "pocket"
  end
  return "computer"
end

function M.safe_path(path)
  return fsx.is_safe_path(path)
end

function M.rednet_signature(token, nonce)
  if not token or token == "" then
    return "none"
  end
  return "placeholder:" .. tostring(nonce or "")
end

function M.validate_rednet(message, token)
  if type(message) ~= "table" then
    return false
  end
  if not message.computer_id or not message.nonce or not message.token_signature then
    return false
  end
  return message.token_signature == M.rednet_signature(token, message.nonce)
end

return M

