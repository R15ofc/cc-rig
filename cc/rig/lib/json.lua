local M = {}

function M.encode(value)
  return textutils.serializeJSON(value)
end

function M.decode(value)
  if value == nil or value == "" then
    return nil
  end
  return textutils.unserializeJSON(value)
end

return M

