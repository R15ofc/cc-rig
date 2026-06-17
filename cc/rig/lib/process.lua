local fsx = require("rig.lib.fsx")

local M = {}
local PROCESS_FILE = "/rig/processes.lua"

local function load_state()
  local state = fsx.load_table(PROCESS_FILE, { apps = {} })
  state.apps = state.apps or {}
  return state
end

local function save_state(state)
  return fsx.save_table(PROCESS_FILE, state)
end

function M.list()
  return load_state().apps
end

function M.start(name, path, args)
  if not name or name == "" then
    return nil, "app name is required"
  end
  if not path or not fs.exists(path) then
    return nil, "app path not found"
  end
  if not multishell then
    return nil, "multishell is unavailable"
  end
  args = args or {}
  local unpacker = table.unpack or unpack
  local tab = multishell.launch({}, path, unpacker(args))
  if tab and multishell.setTitle then
    multishell.setTitle(tab, name)
  end
  local state = load_state()
  state.apps[name] = {
    path = path,
    tab = tab,
    state = "running",
    started_at = os.clock(),
  }
  save_state(state)
  return true, { tab = tab }
end

function M.stop(name)
  local state = load_state()
  if not state.apps[name] then
    return nil, "app is not tracked"
  end
  state.apps[name].state = "stopped"
  state.apps[name].stopped_at = os.clock()
  save_state(state)
  return true, { note = "stop recorded; direct tab termination is not available" }
end

function M.restart(name)
  local state = load_state()
  local app = state.apps[name]
  if not app then
    return nil, "app is not tracked"
  end
  M.stop(name)
  return M.start(name, app.path, {})
end

return M

