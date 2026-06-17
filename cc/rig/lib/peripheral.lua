local M = {}

local function call(target, method, ...)
  if not target or type(target[method]) ~= "function" then
    return nil
  end
  local ok, result = pcall(target[method], ...)
  if ok then
    return result
  end
  return nil
end

function M.list()
  local result = {}
  if not peripheral then
    return result
  end
  for _, name in ipairs(peripheral.getNames()) do
    local types = { peripheral.getType(name) }
    table.insert(result, {
      name = name,
      type = types[1] or "unknown",
      types = types,
    })
  end
  return result
end

function M.inventories()
  local result = {}
  if not peripheral then
    return result
  end
  for _, name in ipairs(peripheral.getNames()) do
    local wrapped = peripheral.wrap(name)
    local size = call(wrapped, "size")
    local list = call(wrapped, "list")
    if type(size) == "number" and type(list) == "table" then
      local used = 0
      for _ in pairs(list) do
        used = used + 1
      end
      table.insert(result, {
        name = name,
        size = size,
        used = used,
        items = list,
      })
    end
  end
  return result
end

function M.energy()
  local result = {}
  if not peripheral then
    return result
  end
  for _, name in ipairs(peripheral.getNames()) do
    local wrapped = peripheral.wrap(name)
    local energy = call(wrapped, "getEnergy")
    local capacity = call(wrapped, "getEnergyCapacity")
    if energy ~= nil or capacity ~= nil then
      table.insert(result, {
        name = name,
        energy = energy,
        capacity = capacity,
      })
    end
  end
  return result
end

function M.fluids()
  local result = {}
  if not peripheral then
    return result
  end
  for _, name in ipairs(peripheral.getNames()) do
    local wrapped = peripheral.wrap(name)
    local tanks = call(wrapped, "tanks")
    if tanks == nil then
      tanks = call(wrapped, "getTanks")
    end
    if type(tanks) == "table" then
      table.insert(result, {
        name = name,
        tanks = tanks,
      })
    end
  end
  return result
end

return M

