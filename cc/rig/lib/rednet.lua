local M = {}

local function is_modem(name)
  if not peripheral then
    return false
  end
  if peripheral.hasType then
    local ok, result = pcall(peripheral.hasType, name, "modem")
    if ok then
      return result
    end
  end
  return peripheral.getType(name) == "modem"
end

function M.open_all()
  local opened = {}
  if not rednet or not peripheral then
    return opened
  end
  for _, name in ipairs(peripheral.getNames()) do
    if is_modem(name) then
      local ok = pcall(rednet.open, name)
      if ok and rednet.isOpen(name) then
        table.insert(opened, name)
      end
    end
  end
  return opened
end

function M.status()
  local result = {}
  if not rednet or not peripheral then
    return result
  end
  for _, name in ipairs(peripheral.getNames()) do
    if is_modem(name) then
      result[name] = rednet.isOpen(name)
    end
  end
  return result
end

return M

