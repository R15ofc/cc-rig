local Bootstrap = {}
local module_cache = rawget(_G, "__rig_module_cache")

if type(module_cache) ~= "table" then
  module_cache = {}
  _G.__rig_module_cache = module_cache
end

local MODULES = {
  fsx = "/rig/lib/fsx.lua",
  http = "/rig/lib/http.lua",
  json = "/rig/lib/json.lua",
  logger = "/rig/lib/logger.lua",
  package = "/rig/lib/package.lua",
  peripheral = "/rig/lib/peripheral.lua",
  process = "/rig/lib/process.lua",
  rednet = "/rig/lib/rednet.lua",
  security = "/rig/lib/security.lua",
  telemetry = "/rig/lib/telemetry.lua",
  ui = "/rig/lib/ui.lua",
  updater = "/rig/lib/updater.lua",
}

local function load_module(module_path)
  local chunk, err = loadfile(module_path)
  if not chunk then
    error(err, 2)
  end
  return chunk()
end

local function normalize_name(module_name)
  module_name = tostring(module_name or "")
  module_name = module_name:gsub("^rig%.lib%.", "")
  module_name = module_name:gsub("^lib%.", "")
  return module_name
end

function Bootstrap.require(module_name)
  local normalized = normalize_name(module_name)
  if module_cache[normalized] ~= nil then
    return module_cache[normalized]
  end
  local module_path = MODULES[normalized]
  if not module_path then
    error("unknown RIG module: " .. tostring(module_name), 2)
  end
  module_cache[normalized] = true
  local module_value = load_module(module_path)
  if module_value == nil then
    module_value = true
  end
  module_cache[normalized] = module_value
  return module_value
end

local function add_package_path(pattern)
  if not package or type(package.path) ~= "string" then
    return
  end
  if not package.path:find(pattern, 1, true) then
    package.path = package.path .. ";" .. pattern
  end
end

function Bootstrap.install()
  add_package_path("/?.lua")
  add_package_path("/?/init.lua")
  _G.rig_require = Bootstrap.require
end

Bootstrap.install()

return Bootstrap
