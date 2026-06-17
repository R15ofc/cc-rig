-- RIG startup hook: begin
if fs.exists("/startup/rig.lua") then
  if shell then
    shell.run("/startup/rig.lua")
  else
    dofile("/startup/rig.lua")
  end
end
-- RIG startup hook: end
