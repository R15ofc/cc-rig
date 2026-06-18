local Net = {}

Net.VERSION = "0.1.0"
Net.CONFIG_PATH = "/rig/devapi/net.lua.cfg"

local function encode(value)
  return tostring(value or ""):gsub("[^%w%-_%.~]", function(character)
    return string.format("%%%02X", string.byte(character))
  end)
end

function Net.read_config()
  if not fs.exists(Net.CONFIG_PATH) then
    return {}
  end
  local ok, result = pcall(dofile, Net.CONFIG_PATH)
  if ok and type(result) == "table" then
    return result
  end
  return {}
end

function Net.write_config(config)
  local dir = fs.getDir(Net.CONFIG_PATH)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
  local handle = fs.open(Net.CONFIG_PATH, "w")
  if not handle then
    return nil, "cannot open " .. Net.CONFIG_PATH
  end
  handle.write("return " .. textutils.serialize(config or {}) .. "\n")
  handle.close()
  return true
end

function Net.set_gateway(url)
  local config = Net.read_config()
  config.gateway_url = tostring(url or ""):gsub("/+$", "")
  return Net.write_config(config)
end

function Net.gateway_url()
  local config = Net.read_config()
  if type(config.gateway_url) == "string" and config.gateway_url ~= "" then
    return config.gateway_url:gsub("/+$", "")
  end
  return nil
end

function Net.json_get(url)
  if not http then
    return nil, "HTTP API is disabled"
  end
  local handle, err = http.get(url, { ["Accept"] = "application/json" })
  if not handle then
    return nil, err or "request failed"
  end
  local body = handle.readAll()
  handle.close()
  if not textutils or not textutils.unserializeJSON then
    return nil, "JSON API is unavailable"
  end
  local result = textutils.unserializeJSON(body)
  if type(result) ~= "table" then
    return nil, "invalid JSON response"
  end
  return result
end

function Net.gateway_get(path, query)
  local base_url = Net.gateway_url()
  if not base_url then
    return nil, "gateway is not configured"
  end
  local separator = query and query ~= "" and "?" or ""
  local result, err = Net.json_get(base_url .. path .. separator .. (query or ""))
  if not result then
    return nil, err
  end
  if not result.ok then
    return nil, result.error or "gateway request failed"
  end
  return result
end

function Net.fetch(url)
  return Net.gateway_get("/fetch", "url=" .. encode(url))
end

function Net.search(query)
  return Net.gateway_get("/search", "q=" .. encode(query))
end

function Net.open_rednet_modems()
  local opened = {}
  if not rednet or not peripheral then
    return opened
  end
  for _, name in ipairs(peripheral.getNames()) do
    local is_modem = false
    if peripheral.hasType then
      local ok, result = pcall(peripheral.hasType, name, "modem")
      is_modem = ok and result
    else
      is_modem = peripheral.getType(name) == "modem"
    end
    if is_modem then
      pcall(rednet.open, name)
      if rednet.isOpen(name) then
        table.insert(opened, name)
      end
    end
  end
  return opened
end

function Net.request(protocol, message, reply_protocol, timeout)
  Net.open_rednet_modems()
  if not rednet then
    return nil, "rednet API is unavailable"
  end
  rednet.broadcast(message or {}, protocol)
  local _, response = rednet.receive(reply_protocol, timeout or 1)
  if response == nil then
    return nil, "timeout"
  end
  return response
end

return Net
