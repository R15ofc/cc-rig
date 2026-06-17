local M = {}

local function parent_dir(path)
  local dir = fs.getDir(path)
  if dir ~= nil and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

function M.exists(path)
  return fs.exists(path)
end

function M.ensure_dir(path)
  if not fs.exists(path) then
    fs.makeDir(path)
  end
end

function M.read_file(path)
  if not fs.exists(path) then
    return nil, "file not found"
  end
  local handle = fs.open(path, "r")
  if not handle then
    return nil, "cannot open file"
  end
  local data = handle.readAll()
  handle.close()
  return data
end

function M.write_file(path, data)
  parent_dir(path)
  local handle = fs.open(path, "w")
  if not handle then
    return nil, "cannot open file"
  end
  handle.write(data or "")
  handle.close()
  return true
end

function M.append_file(path, data)
  parent_dir(path)
  local handle = fs.open(path, "a")
  if not handle then
    return nil, "cannot open file"
  end
  handle.write(data or "")
  handle.close()
  return true
end

function M.load_table(path, default)
  local data = M.read_file(path)
  if not data then
    return default
  end
  local chunk, err = load(data, path, "t", {})
  if not chunk then
    return default, err
  end
  local ok, value = pcall(chunk)
  if not ok or type(value) ~= "table" then
    return default, value
  end
  return value
end

function M.save_table(path, value)
  return M.write_file(path, "return " .. textutils.serialize(value or {}) .. "\n")
end

function M.normalize(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  path = path:gsub("\\", "/")
  if path:sub(1, 1) ~= "/" then
    path = "/" .. path
  end
  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then
      return nil
    elseif part ~= "." and part ~= "" then
      table.insert(parts, part)
    end
  end
  return "/" .. table.concat(parts, "/")
end

function M.is_safe_path(path)
  local normalized = M.normalize(path)
  if not normalized then
    return false
  end
  return normalized:sub(1, 5) == "/rig/"
    or normalized:sub(1, 5) == "/bin/"
    or normalized:sub(1, 9) == "/startup/"
    or normalized == "/startup.lua"
end

function M.delete(path)
  if fs.exists(path) then
    fs.delete(path)
  end
  return true
end

return M
