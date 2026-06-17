local M = {}

function M.print_table(rows)
  for _, row in ipairs(rows or {}) do
    print(table.concat(row, "  "))
  end
end

function M.print_kv(title, value)
  print(tostring(title) .. ": " .. tostring(value))
end

function M.ok(message)
  print("[OK] " .. tostring(message))
end

function M.fail(message)
  print("[ERR] " .. tostring(message))
end

return M

