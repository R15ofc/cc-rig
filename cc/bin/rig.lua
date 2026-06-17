local args = { ... }
local unpacker = table.unpack or unpack

if shell then
  shell.run("/rig/rig.lua", unpacker(args))
else
  dofile("/rig/rig.lua")
end

