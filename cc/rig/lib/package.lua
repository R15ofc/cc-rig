local fsx = dofile("/rig/bootstrap.lua").require("fsx")
local httpc = dofile("/rig/bootstrap.lua").require("http")
local security = dofile("/rig/bootstrap.lua").require("security")

local M = {}
local LOCK_PATH = "/rig/lock.lua"

local function load_lock()
  local lock = fsx.load_table(LOCK_PATH, { packages = {} })
  lock.packages = lock.packages or {}
  return lock
end

local function save_lock(lock)
  return fsx.save_table(LOCK_PATH, lock)
end

local function identity()
  local current = security.load_identity()
  if current and current.hub_url then
    return current
  end
  local config = security.load_config()
  if config and config.hub_url then
    return {
      hub_url = config.hub_url,
      token = config.token,
    }
  end
  return nil, "hub URL is not configured"
end

local function timestamp()
  if os.epoch then
    return os.epoch("utc") / 1000
  end
  return os.clock()
end

local function package_file_url(hub_url, manifest, file)
  local source = file.source or file.url or file.path
  source = tostring(source):gsub("^/+", "")
  if source:sub(1, 9) == "packages/" then
    return httpc.join(hub_url, source)
  end
  return httpc.join(hub_url, "/packages/" .. manifest.name .. "/" .. manifest.version .. "/" .. source)
end

local function write_launcher(command, target)
  local path = "/bin/" .. command .. ".lua"
  local body = table.concat({
    "dofile(\"/rig/bootstrap.lua\")",
    "local args = { ... }",
    "local unpacker = table.unpack or unpack",
    "if shell then",
    "  shell.run(" .. string.format("%q", target) .. ", unpacker(args))",
    "else",
    "  dofile(" .. string.format("%q", target) .. ")",
    "end",
    "",
  }, "\n")
  return fsx.write_file(path, body), path
end

function M.registry()
  local current, err = identity()
  if not current then
    return nil, err
  end
  return httpc.get(httpc.join(current.hub_url, "/api/packages"), current.token)
end

function M.search(query)
  local packages, err = M.registry()
  if not packages then
    return nil, err
  end
  query = tostring(query or ""):lower()
  local result = {}
  for _, pkg in ipairs(packages) do
    local haystack = (tostring(pkg.name) .. " " .. tostring(pkg.description)):lower()
    if query == "" or haystack:find(query, 1, true) then
      table.insert(result, pkg)
    end
  end
  return result
end

function M.info(name)
  if not name or name == "" then
    return nil, "package name is required"
  end
  local current, err = identity()
  if not current then
    return nil, err
  end
  return httpc.get(httpc.join(current.hub_url, "/api/packages/" .. name), current.token)
end

function M.manifest(name, version)
  if not name or name == "" then
    return nil, "package name is required"
  end
  local current, err = identity()
  if not current then
    return nil, err
  end
  version = version or "latest"
  return httpc.get(httpc.join(current.hub_url, "/api/packages/" .. name .. "/" .. version .. "/manifest"), current.token)
end

function M.install(name, version, seen)
  if not name or name == "" then
    return nil, "package name is required"
  end
  seen = seen or {}
  if seen[name] then
    return true
  end
  seen[name] = true

  local manifest, err = M.manifest(name, version or "latest")
  if not manifest then
    return nil, err
  end

  for _, dep in ipairs(manifest.dependencies or {}) do
    if type(dep) == "table" then
      local ok, dep_err = M.install(dep.name, dep.version or "latest", seen)
      if not ok then
        return nil, dep_err
      end
    else
      local ok, dep_err = M.install(dep, "latest", seen)
      if not ok then
        return nil, dep_err
      end
    end
  end

  local current, id_err = identity()
  if not current then
    return nil, id_err
  end

  local installed_files = {}
  for _, file in ipairs(manifest.files or {}) do
    local target = fsx.normalize(file.path)
    if not target or not fsx.is_safe_path(target) then
      return nil, "unsafe package path: " .. tostring(file.path)
    end
    local body, download_err = httpc.raw_get(package_file_url(current.hub_url, manifest, file), current.token)
    if body == nil then
      return nil, download_err
    end
    local ok, write_err = fsx.write_file(target, body)
    if not ok then
      return nil, write_err
    end
    table.insert(installed_files, target)
  end

  local bins = {}
  for command, target in pairs(manifest.bin or {}) do
    local normalized = fsx.normalize(target)
    if not normalized or not fsx.is_safe_path(normalized) then
      return nil, "unsafe bin target: " .. tostring(target)
    end
    local ok, launcher_path = write_launcher(command, normalized)
    if not ok then
      return nil, launcher_path
    end
    bins[command] = launcher_path
  end

  local lock = load_lock()
  lock.packages[manifest.name] = {
    version = manifest.version,
    files = installed_files,
    bins = bins,
    installed_at = timestamp(),
  }
  save_lock(lock)
  return true, manifest
end

function M.remove(name)
  if not name or name == "" then
    return nil, "package name is required"
  end
  local lock = load_lock()
  local installed = lock.packages[name]
  if not installed then
    return nil, "package is not installed"
  end
  for _, path in ipairs(installed.files or {}) do
    if fsx.is_safe_path(path) then
      fsx.delete(path)
    end
  end
  for _, path in pairs(installed.bins or {}) do
    if fsx.is_safe_path(path) then
      fsx.delete(path)
    end
  end
  lock.packages[name] = nil
  save_lock(lock)
  return true
end

function M.list()
  return load_lock().packages
end

function M.upgrade(name)
  if name and name ~= "" then
    return M.install(name, "latest")
  end
  local lock = load_lock()
  for package_name in pairs(lock.packages) do
    local ok, err = M.install(package_name, "latest")
    if not ok then
      return nil, err
    end
  end
  return true
end

return M
