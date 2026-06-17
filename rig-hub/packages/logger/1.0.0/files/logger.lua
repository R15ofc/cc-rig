dofile("/rig/bootstrap.lua")

local logger = require("rig.lib.logger")

local message = table.concat({ ... }, " ")
if message == "" then
  message = "logger package test"
end

logger.info("logger", message)
print("Logged: " .. message)
