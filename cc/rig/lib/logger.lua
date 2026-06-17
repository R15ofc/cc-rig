local fsx = dofile("/rig/bootstrap.lua").require("fsx")
local json = dofile("/rig/bootstrap.lua").require("json")

local M = {}
local LOG_DIR = "/rig/logs"

local function timestamp()
  if os.epoch then
    return os.epoch("utc") / 1000
  end
  return os.clock()
end

local function log_path()
  local day = "runtime"
  if os.date then
    day = os.date("%Y%m%d")
  end
  return LOG_DIR .. "/" .. day .. ".log"
end

function M.write(level, app, message)
  fsx.ensure_dir(LOG_DIR)
  local entry = {
    ts = timestamp(),
    level = tostring(level or "info"),
    app = tostring(app or "rig"),
    message = tostring(message or ""),
  }
  fsx.append_file(log_path(), json.encode(entry) .. "\n")
  return entry
end

function M.info(app, message)
  return M.write("info", app, message)
end

function M.warn(app, message)
  return M.write("warn", app, message)
end

function M.error(app, message)
  return M.write("error", app, message)
end

function M.read(limit)
  fsx.ensure_dir(LOG_DIR)
  local entries = {}
  local files = fs.list(LOG_DIR)
  table.sort(files)
  for _, file in ipairs(files) do
    local path = LOG_DIR .. "/" .. file
    if not fs.isDir(path) then
      local handle = fs.open(path, "r")
      if handle then
        while true do
          local line = handle.readLine()
          if not line then
            break
          end
          local entry = json.decode(line)
          if entry then
            table.insert(entries, entry)
          end
        end
        handle.close()
      end
    end
  end
  limit = limit or 100
  while #entries > limit do
    table.remove(entries, 1)
  end
  return entries
end

return M

