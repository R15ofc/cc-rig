local function add_rig_package_paths()
  if not package or type(package.path) ~= "string" then
    return
  end
  for _, pattern in ipairs({ "/?.lua", "/?/init.lua" }) do
    if not package.path:find(pattern, 1, true) then
      package.path = package.path .. ";" .. pattern
    end
  end
end

add_rig_package_paths()

local logger = require("rig.lib.logger")

local message = table.concat({ ... }, " ")
if message == "" then
  message = "logger package test"
end

logger.info("logger", message)
print("Logged: " .. message)
