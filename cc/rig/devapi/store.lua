local Store = {}

Store.VERSION = "0.1.0"
Store.PROTOCOL = "dock.store"
Store.REPLY_PROTOCOL = "dock.store.reply"

Store.BUILTIN_CATALOG = {
  {
    id = "luma",
    name = "Luma Browser",
    trust = "verified",
    description = "Browser for Luma pages, search, packages, and HTTP.",
    installer = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/luma-installer.lua",
    source = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/cc",
  },
}

local function load_net()
  if fs.exists("/rig/bootstrap.lua") then
    local ok, module = pcall(function()
      return dofile("/rig/bootstrap.lua").require("devapi.net")
    end)
    if ok then
      return module
    end
  end
  if fs.exists("/rig/devapi/net.lua") then
    local ok, module = pcall(dofile, "/rig/devapi/net.lua")
    if ok then
      return module
    end
  end
  return nil
end

function Store.catalog()
  local net = load_net()
  if net then
    local response = net.request(Store.PROTOCOL, { type = "catalog" }, Store.REPLY_PROTOCOL, 1)
    if type(response) == "table" and response.ok and type(response.apps) == "table" then
      return response.apps, "server"
    end
  end
  return Store.BUILTIN_CATALOG, "offline"
end

function Store.trust_label(app)
  local trust = app and app.trust or "unreviewed"
  if trust == "verified" then
    return "VERIFIED"
  elseif trust == "blocked" then
    return "BLOCKED"
  end
  return "UNREVIEWED"
end

function Store.find(catalog, id)
  for _, app in ipairs(catalog or {}) do
    if app.id == id then
      return app
    end
  end
  return nil
end

return Store
