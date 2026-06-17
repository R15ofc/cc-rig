local fsx = dofile("/rig/bootstrap.lua").require("fsx")
local httpc = dofile("/rig/bootstrap.lua").require("http")

local M = {}

M.DEFAULT_SOURCE_URL = "https://raw.githubusercontent.com/R15ofc/cc-rig/main/cc"

M.FILES = {
  { source = "rig/bootstrap.lua", target = "/rig/bootstrap.lua" },
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

local function join_url(base_url, path)
  base_url = tostring(base_url or M.DEFAULT_SOURCE_URL):gsub("/+$", "")
  path = tostring(path or ""):gsub("^/+", "")
  return base_url .. "/" .. path
end

local function temp_path(target)
  return "/rig/.update/" .. target:gsub("^/+", "")
end

local function ensure_parent(path)
  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
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

function M.install_startup()
  fsx.ensure_dir("/startup")
  if fs.exists("/startup.lua") and not fs.exists("/startup.lua.rig.bak") then
    fs.copy("/startup.lua", "/startup.lua.rig.bak")
  end
  local existing = fsx.read_file("/startup.lua") or ""
  return fsx.write_file("/startup.lua", replace_block(existing))
end

function M.update(source_url, on_progress)
  source_url = (source_url and source_url ~= "") and source_url or M.DEFAULT_SOURCE_URL
  fsx.delete("/rig/.update")
  fsx.ensure_dir("/rig/.update")

  for index, file in ipairs(M.FILES) do
    if on_progress then
      on_progress("download", index - 1, #M.FILES, file.source)
    end
    local body, err = httpc.raw_get(join_url(source_url, file.source))
    if body == nil then
      fsx.delete("/rig/.update")
      return nil, "download failed for " .. file.source .. ": " .. tostring(err)
    end
    local ok, write_err = fsx.write_file(temp_path(file.target), body)
    if not ok then
      fsx.delete("/rig/.update")
      return nil, "write failed for " .. file.target .. ": " .. tostring(write_err)
    end
    if on_progress then
      on_progress("download", index, #M.FILES, file.source)
    end
  end

  for index, file in ipairs(M.FILES) do
    if on_progress then
      on_progress("apply", index - 1, #M.FILES, file.target)
    end
    fsx.delete(file.target)
    ensure_parent(file.target)
    fs.move(temp_path(file.target), file.target)
    if on_progress then
      on_progress("apply", index, #M.FILES, file.target)
    end
  end
  fsx.delete("/rig/.update")
  M.install_startup()
  if on_progress then
    on_progress("complete", #M.FILES, #M.FILES, "complete")
  end
  return true, {
    source_url = source_url,
    count = #M.FILES,
  }
end

return M
