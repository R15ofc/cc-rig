local DEFAULT_SOURCE_URL = "https://raw.githubusercontent.com/R15ofc/cc-rig/main/cc"
local TEMP_DIR = "/rig/.installer"

local FILES = {
  { source = "rig/bootstrap.lua", target = "/rig/bootstrap.lua" },
  { source = "rig/rig.lua", target = "/rig/rig.lua" },
  { source = "rig/agent.lua", target = "/rig/agent.lua" },
  { source = "rig/gateway.lua", target = "/rig/gateway.lua" },
  { source = "rig/devapi/app.lua", target = "/rig/devapi/app.lua" },
  { source = "rig/devapi/net.lua", target = "/rig/devapi/net.lua" },
  { source = "rig/devapi/store.lua", target = "/rig/devapi/store.lua" },
  { source = "rig/devapi/ui.lua", target = "/rig/devapi/ui.lua" },
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
local SPINNER = { "/", "-", "\\", "|" }

local ROOT_STARTUP_BLOCK = START_MARK .. "\n" .. [[
if fs.exists("/startup/rig.lua") then
  if shell then
    shell.run("/startup/rig.lua")
  else
    dofile("/startup/rig.lua")
  end
end
]] .. END_MARK .. "\n"

local status_line = nil

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

local function write_status(text)
  if term and term.getCursorPos and term.setCursorPos and term.clearLine and term.write then
    local _, current_y = term.getCursorPos()
    status_line = status_line or current_y
    term.setCursorPos(1, status_line)
    term.clearLine()
    term.write(fit_line(text))
  end
end

local function finish_status(text)
  if term and term.getCursorPos and term.setCursorPos then
    write_status(text)
    local _, current_y = term.getCursorPos()
    term.setCursorPos(1, current_y + 1)
    status_line = nil
  else
    print(text)
  end
end

local function progress_text(done, total, label, frame)
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
    "RIG %s [%s%s] %6.2f%% %s",
    frame or " ",
    string.rep("#", filled),
    string.rep("-", width - filled),
    percent,
    label or ""
  )
end

local function print_header(source_url)
  print("RIG Dev API Installer")
  print("Source: " .. source_url)
  print("Target: /rig/devapi, /rig/lib, /bin")
  print("")
end

local function print_step(message)
  print("==> " .. message)
end

local function print_ok(message)
  print("OK  " .. message)
end

local function print_error(message)
  print("ERR " .. message)
end

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

local function blocking_download(url)
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

local function download(url, label, index, total)
  if not http then
    return nil, "HTTP API is disabled"
  end
  if not http.request or not os.pullEvent or not os.startTimer then
    write_status(progress_text(index - 1, total, label, SPINNER[1]))
    local body, err = blocking_download(url)
    if body == nil then
      return nil, err
    end
    finish_status(progress_text(index, total, label, " "))
    return body
  end

  local request_ok, request_err = http.request(url, nil, { ["Accept"] = "text/plain" })
  if request_ok == false or request_ok == nil then
    return nil, request_err or "request failed"
  end

  local frame = 1
  local timer_id = os.startTimer(0.12)
  write_status(progress_text(index - 1, total, label, SPINNER[frame]))

  while true do
    local event, first, second, third = os.pullEvent()
    if event == "timer" and first == timer_id then
      frame = frame + 1
      if frame > #SPINNER then
        frame = 1
      end
      write_status(progress_text(index - 1, total, label, SPINNER[frame]))
      timer_id = os.startTimer(0.12)
    elseif event == "http_success" and first == url then
      local handle = second
      local body = handle.readAll()
      local code = 200
      if handle.getResponseCode then
        code = handle.getResponseCode()
      end
      handle.close()
      if code < 200 or code >= 300 then
        return nil, "HTTP " .. tostring(code)
      end
      finish_status(progress_text(index, total, label, " "))
      return body or ""
    elseif event == "http_failure" and first == url then
      local reason = second or "request failed"
      local handle = third
      if handle and handle.close then
        handle.close()
      end
      return nil, tostring(reason)
    end
  end
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

  print_step("Downloading core files")
  for index, file in ipairs(FILES) do
    local url = join_url(source_url, file.source)
    local body, err = download(url, file.source, index, #FILES)
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

  print_step("Applying files")
  for index, file in ipairs(FILES) do
    write_status(progress_text(index - 1, #FILES, file.target, SPINNER[((index - 1) % #SPINNER) + 1]))
    if fs.exists(file.target) then
      fs.delete(file.target)
    end
    ensure_parent(file.target)
    fs.move(temp_path(file.target), file.target)
    finish_status(progress_text(index, #FILES, file.target, " "))
  end
  fs.delete(TEMP_DIR)
  return true
end

local function register_if_requested(positional)
  local hub_url = positional[1]
  local token = positional[2]
  if not hub_url or not token then
    print("")
    print("Next: rig os install dock")
    print("Open: dock")
    return
  end
  if not shell then
    print("Registration requires the shell API. Run /bin/rig.lua register manually.")
    return
  end
  print_step("Registering device")
  local register_ok, register_err = pcall(shell.run, "/bin/rig.lua", "register", hub_url, token)
  if not register_ok then
    print_error("Registration command failed: " .. tostring(register_err))
    print("Run manually: /bin/rig.lua register <hub_url> <token>")
    return
  end
  print_step("Installing startup hook")
  local startup_ok, startup_err = pcall(shell.run, "/bin/rig.lua", "startup", "install")
  if not startup_ok then
    print_error("Startup command failed: " .. tostring(startup_err))
    print("Run manually: /bin/rig.lua startup install")
  end
end

local source_url, positional = parse_args({ ... })

print_header(source_url)

local ok, err = install_files(source_url)
if not ok then
  print_error("Installation failed: " .. tostring(err))
  return
end

print_step("Installing startup integration")
install_startup()
write_default_config()
append_shell_path("/bin")

print_ok("RIG dev API installation complete")
print("Update command: rig update")
register_if_requested(positional)
