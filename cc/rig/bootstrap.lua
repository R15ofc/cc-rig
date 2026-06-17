local Bootstrap = {}

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

  if not package or type(package.preload) ~= "table" then
    return
  end

  for module_name, module_path in pairs(MODULES) do
    local preload_path = module_path
    package.preload[module_name] = function()
      return load_module(preload_path)
    end
  end
end

Bootstrap.install()

return Bootstrap

