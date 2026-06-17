local json = require("rig.lib.json")

local M = {}

local function headers(token)
  local result = {
    ["Accept"] = "application/json",
    ["Content-Type"] = "application/json",
  }
  if token and token ~= "" then
    result["Authorization"] = "Bearer " .. token
  end
  return result
end

local function parse_json_response(handle)
  local body = handle.readAll()
  local code = 200
  if handle.getResponseCode then
    code = handle.getResponseCode()
  end
  handle.close()
  if code < 200 or code >= 300 then
    return nil, "HTTP " .. tostring(code) .. ": " .. tostring(body), code
  end
  if body == nil or body == "" then
    return {}, nil, code
  end
  local decoded = json.decode(body)
  if decoded == nil then
    return nil, "invalid JSON response", code
  end
  return decoded, nil, code
end

function M.join(base_url, path)
  base_url = tostring(base_url or ""):gsub("/+$", "")
  path = tostring(path or ""):gsub("^/+", "")
  return base_url .. "/" .. path
end

function M.get(url, token)
  if not http then
    return nil, "HTTP API is disabled"
  end
  local handle, err = http.get(url, headers(token))
  if not handle then
    return nil, err or "request failed"
  end
  return parse_json_response(handle)
end

function M.post(url, body, token)
  if not http then
    return nil, "HTTP API is disabled"
  end
  local payload = json.encode(body or {})
  local handle, err = http.post(url, payload, headers(token))
  if not handle then
    return nil, err or "request failed"
  end
  return parse_json_response(handle)
end

function M.raw_get(url, token)
  if not http then
    return nil, "HTTP API is disabled"
  end
  local handle, err = http.get(url, headers(token))
  if not handle then
    return nil, err or "request failed"
  end
  local body = handle.readAll()
  local code = 200
  if handle.getResponseCode then
    code = handle.getResponseCode()
  end
  handle.close()
  if code < 200 or code >= 300 then
    return nil, "HTTP " .. tostring(code)
  end
  return body or ""
end

return M

