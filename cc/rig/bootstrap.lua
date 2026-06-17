local Bootstrap = {}
local original_require = require
local loaded_modules = {}

local MODULES = {
  ["rig.lib.fsx"] = "/rig/lib/fsx.lua",
  ["rig.lib.http"] = "/rig/lib/http.lua",
  ["rig.lib.json"] = "/rig/lib/json.lua",
  ["rig.lib.logger"] = "/rig/lib/logger.lua",
  ["rig.lib.package"] = "/rig/lib/package.lua",
  ["rig.lib.peripheral"] = "/rig/lib/peripheral.lua",
  ["rig.lib.process"] = "/rig/lib/process.lua",
  ["rig.lib.rednet"] = "/rig/lib/rednet.lua",
  ["rig.lib.security"] = "/rig/lib/security.lua",
  ["rig.lib.telemetry"] = "/rig/lib/telemetry.lua",
  ["rig.lib.ui"] = "/rig/lib/ui.lua",
  ["rig.lib.updater"] = "/rig/lib/updater.lua",
}

local function load_module(module_path)
  local chunk, err = loadfile(module_path)
  if not chunk then
    error(err, 2)
  end
  return chunk()
end

local function require_rig_module(module_name)
  if loaded_modules[module_name] ~= nil then
    return loaded_modules[module_name]
  end
  local module_path = MODULES[module_name]
  if not module_path then
    return nil
  end
  local module_value = load_module(module_path)
  if module_value == nil then
    module_value = true
  end
  loaded_modules[module_name] = module_value
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

  if package and type(package.loaded) == "table" then
    loaded_modules = package.loaded
  end

  if package and type(package.preload) == "table" then
    for module_name in pairs(MODULES) do
      local preload_name = module_name
      package.preload[module_name] = function()
        return require_rig_module(preload_name)
      end
    end
  end

  _G.require = function(module_name)
    local rig_module = require_rig_module(module_name)
    if rig_module ~= nil then
      return rig_module
    end
    return original_require(module_name)
  end
end

Bootstrap.install()

return Bootstrap
