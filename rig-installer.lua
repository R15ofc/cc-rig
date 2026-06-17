local DEFAULT_SOURCE_URL = "https://raw.githubusercontent.com/R15ofc/cc-rig/main/cc"
local TEMP_DIR = "/rig/.installer"

local FILES = {
  { source = "rig/rig.lua", target = "/rig/rig.lua" },
  { source = "rig/agent.lua", target = "/rig/agent.lua" },
  { source = "rig/gateway.lua", target = "/rig/gateway.lua" },
  { source = "rig/lib/fsx.lua", target = "/rig/lib/fsx.lua" },
  { source = "rig/lib/http.lua", target = "/rig/lib/http.lua" },
  { source = "rig/lib/json.lua", target = "/rig/lib/json.lua" },
  { source = "rig/lib/logger.lua", target = "/rig/lib/logger.lua" },
  { source = "rig/lib/package.lua", target = "/rig/lib/package.lua" },
  { source = "rig/lib/peripheral.lua", target = "/rig/lib/peripheral.lua" },
  { source = "rig/lib/process.lua", target = "/rig/lib/process.lua" },
  { source = "rig/lib/rednet.lua", target = "/rig/lib/rednet.lua" },
  { source = "rig/lib/security.lua", target = "/rig/lib/security.lua" },
  { source = "rig/lib/telemetry.lua", target = "/rig/lib/telemetry.lua" },
  { source = "rig/lib/ui.lua", target = "/rig/lib/ui.lua" },
  { source = "rig/lib/updater.lua", target = "/rig/lib/updater.lua" },
  { source = "bin/rig.lua", target = "/bin/rig.lua" },
  { source = "startup/rig.lua", target = "/startup/rig.lua" },
}

local START_MARK = "-- RIG startup hook: begin"
local END_MARK = "-- RIG startup hook: end"

local ROOT_STARTUP_BLOCK = START_MARK .. "\n" .. [[
if fs.exists("/startup/rig.lua") then
  if shell then
    shell.run("/startup/rig.lua")
  else
    dofile("/startup/rig.lua")
  end
end
]] .. END_MARK .. "\n"

local function parse_args(raw)
  local source_url = DEFAULT_SOURCE_URL
  local positional = {}
  local index = 1
  while index <= #raw do
    local value = raw[index]
    if value == "--source" then
      source_url = raw[index + 1] or source_url
      index = index + 2
    else
      table.insert(positional, value)
      index = index + 1
    end
  end
  return source_url, positional
end

local function ensure_parent(path)
  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

local function read_file(path)
  if not fs.exists(path) then
    return nil
  end
  local handle = fs.open(path, "r")
  if not handle then
    return nil
  end
  local data = handle.readAll()
  handle.close()
  return data
end

local function write_file(path, data)
  ensure_parent(path)
  local handle = fs.open(path, "w")
  if not handle then
    return nil, "cannot open " .. path
  end
  handle.write(data or "")
  handle.close()
  return true
end

local function join_url(base_url, path)
  base_url = tostring(base_url or DEFAULT_SOURCE_URL):gsub("/+$", "")
  path = tostring(path or ""):gsub("^/+", "")
  return base_url .. "/" .. path
end

local function temp_path(target)
  return TEMP_DIR .. "/" .. target:gsub("^/+", "")
end

local function download(url)
  if not http then
    return nil, "HTTP API is disabled"
  end
  local handle, err = http.get(url, { ["Accept"] = "text/plain" })
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

local function replace_block(existing)
  existing = existing or ""
  local start_pos = existing:find(START_MARK, 1, true)
  if start_pos then
    local end_start, end_finish = existing:find(END_MARK, start_pos, true)
    if end_start then
      return existing:sub(1, start_pos - 1) .. ROOT_STARTUP_BLOCK .. existing:sub(end_finish + 1)
    end
  end
  if existing:find("/startup/rig.lua", 1, true) then
    return existing
  end
  if existing ~= "" and existing:sub(-1) ~= "\n" then
    existing = existing .. "\n"
  end
  return existing .. "\n" .. ROOT_STARTUP_BLOCK
end

local function install_startup()
  if not fs.exists("/startup") then
    fs.makeDir("/startup")
  end
  if fs.exists("/startup.lua") and not fs.exists("/startup.lua.rig.bak") then
    fs.copy("/startup.lua", "/startup.lua.rig.bak")
  end
  local existing = read_file("/startup.lua") or ""
  return write_file("/startup.lua", replace_block(existing))
end

local function append_shell_path(path)
  if not shell or not shell.path or not shell.setPath then
    return
  end
  local current = shell.path()
  for part in string.gmatch(current, "[^:]+") do
    if part == path then
      return
    end
  end
  shell.setPath(current .. ":" .. path)
end

local function write_default_config()
  if fs.exists("/rig/config.lua") then
    return
  end
  write_file("/rig/config.lua", "return " .. textutils.serialize({ agent_enabled = false }) .. "\n")
end

local function install_files(source_url)
  if fs.exists(TEMP_DIR) then
    fs.delete(TEMP_DIR)
  end
  fs.makeDir(TEMP_DIR)

  for index, file in ipairs(FILES) do
    local url = join_url(source_url, file.source)
    print("Downloading " .. tostring(index) .. "/" .. tostring(#FILES) .. ": " .. file.source)
    local body, err = download(url)
    if body == nil then
      fs.delete(TEMP_DIR)
      return nil, "download failed for " .. file.source .. ": " .. tostring(err)
    end
    local ok, write_err = write_file(temp_path(file.target), body)
    if not ok then
      fs.delete(TEMP_DIR)
      return nil, write_err
    end
  end

  for _, file in ipairs(FILES) do
    if fs.exists(file.target) then
      fs.delete(file.target)
    end
    ensure_parent(file.target)
    fs.move(temp_path(file.target), file.target)
  end
  fs.delete(TEMP_DIR)
  return true
end

local function register_if_requested(positional)
  local hub_url = positional[1]
  local token = positional[2]
  if not hub_url or not token then
    print("Next: rig register <hub_url> <token>")
    print("Then: rig startup install")
    return
  end
  if not shell then
    print("Registration needs the shell API. Run /bin/rig.lua register manually.")
    return
  end
  shell.run("/bin/rig.lua", "register", hub_url, token)
  shell.run("/bin/rig.lua", "startup", "install")
end

local source_url, positional = parse_args({ ... })

print("RIG installer")
print("Source: " .. source_url)

local ok, err = install_files(source_url)
if not ok then
  print("Install failed: " .. tostring(err))
  return
end

install_startup()
write_default_config()
append_shell_path("/bin")

print("RIG core installed.")
print("Future updates: rig update")
register_if_requested(positional)

