dofile("/rig/bootstrap.lua")

local logger = dofile("/rig/bootstrap.lua").require("logger")

local message = table.concat({ ... }, " ")
if message == "" then
  message = "logger package test"
end

logger.info("logger", message)
print("Logged: " .. message)
