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

local args = { ... }
local unpacker = table.unpack or unpack

if shell then
  shell.run("/rig/rig.lua", unpacker(args))
else
  dofile("/rig/rig.lua")
end
