local M = {}

local function can_color()
  return term and term.isColor and term.isColor()
end

local function with_color(fg, bg, callback)
  if can_color() then
    local old_fg = term.getTextColor()
    local old_bg = term.getBackgroundColor()
    if fg then
      term.setTextColor(fg)
    end
    if bg then
      term.setBackgroundColor(bg)
    end
    callback()
    term.setTextColor(old_fg)
    term.setBackgroundColor(old_bg)
  else
    callback()
  end
end

function M.title(name, version)
  with_color(colors.cyan, nil, function()
    print(tostring(name) .. (version and (" " .. tostring(version)) or ""))
  end)
end

function M.section(name)
  print("")
  with_color(colors.lightBlue, nil, function()
    print(tostring(name))
  end)
end

function M.command(command, description)
  local left = "  " .. tostring(command)
  local padding = string.rep(" ", math.max(1, 24 - #left))
  with_color(colors.white, nil, function()
    term.write(left)
  end)
  with_color(colors.lightGray, nil, function()
    print(padding .. tostring(description or ""))
  end)
end

function M.print_table(rows)
  for _, row in ipairs(rows or {}) do
    print(table.concat(row, "  "))
  end
end

function M.print_kv(title, value)
  local label = tostring(title)
  local padding = string.rep(" ", math.max(1, 16 - #label))
  with_color(colors.lightGray, nil, function()
    term.write(label .. padding)
  end)
  print(tostring(value))
end

function M.ok(message)
  with_color(colors.lime, nil, function()
    term.write("OK   ")
  end)
  print(tostring(message))
end

function M.fail(message)
  with_color(colors.red, nil, function()
    term.write("ERR  ")
  end)
  print(tostring(message))
end

function M.warn(message)
  with_color(colors.orange, nil, function()
    term.write("WARN ")
  end)
  print(tostring(message))
end

return M
