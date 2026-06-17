local fsx = require("rig.lib.fsx")
local peripheral_info = require("rig.lib.peripheral")
local process = require("rig.lib.process")
local rednet_info = require("rig.lib.rednet")

local M = {}

local function safe_call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, result = pcall(fn, ...)
  if ok then
    return result
  end
  return nil
end

local function disk()
  return {
    free = safe_call(fs.getFreeSpace, "/"),
    capacity = safe_call(fs.getCapacity, "/"),
  }
end

local function gps_position()
  if not gps or type(gps.locate) ~= "function" then
    return nil
  end
  local x, y, z = gps.locate(1)
  if not x then
    return nil
  end
  return { x = x, y = y, z = z }
end

local function redstone_inputs()
  local result = {}
  if not redstone then
    return result
  end
  for _, side in ipairs({ "top", "bottom", "left", "right", "front", "back" }) do
    result[side] = safe_call(redstone.getInput, side)
  end
  return result
end

local function turtle_info()
  if not turtle then
    return nil
  end
  local inventory = {}
  for slot = 1, 16 do
    inventory[slot] = {
      count = safe_call(turtle.getItemCount, slot),
      space = safe_call(turtle.getItemSpace, slot),
      detail = safe_call(turtle.getItemDetail, slot),
    }
  end
  return {
    fuel = safe_call(turtle.getFuelLevel),
    fuel_limit = safe_call(turtle.getFuelLimit),
    inventory = inventory,
  }
end

function M.collect()
  local lock = fsx.load_table("/rig/lock.lua", { packages = {} })
  local data = {
    computer_id = os.getComputerID(),
    computer_label = os.getComputerLabel and os.getComputerLabel() or nil,
    uptime = os.clock(),
    craftos_version = _HOST,
    disk = disk(),
    gps = gps_position(),
    peripherals = peripheral_info.list(),
    rednet = rednet_info.status(),
    inventories = peripheral_info.inventories(),
    energy = peripheral_info.energy(),
    fluids = peripheral_info.fluids(),
    turtle = turtle_info(),
    redstone = redstone_inputs(),
    installed_packages = lock.packages or {},
    running_apps = process.list(),
  }
  if shell and shell.path then
    data.shell_path = shell.path()
  end
  return data
end

return M

