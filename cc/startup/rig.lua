local function append_path(entry)
  if shell and shell.path and shell.setPath then
    local current = shell.path()
    for part in string.gmatch(current, "[^:]+") do
      if part == entry then
        return
      end
    end
    shell.setPath(current .. ":" .. entry)
  end
end

append_path("/bin")

local ok_bootstrap = pcall(dofile, "/rig/bootstrap.lua")
if not ok_bootstrap then
  return
end

local ok_security, security = pcall(require, "rig.lib.security")
if not ok_security then
  return
end

local config = security.load_config()
if config.agent_enabled == false then
  return
end

if fs.exists("/rig/agent.lua") and multishell then
  local tab = multishell.launch({}, "/rig/agent.lua")
  if tab and multishell.setTitle then
    multishell.setTitle(tab, "RIG Agent")
  end
end
