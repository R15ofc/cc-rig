local App = {}

App.VERSION = "0.1.0"

function App.ensure_parent(path)
  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

function App.read_file(path)
  if not fs.exists(path) then
    return nil
  end
  local handle = fs.open(path, "r")
  if not handle then
    return nil
  end
  local data = handle.readAll()
  handle.close()
  return data
end

function App.write_file(path, data)
  App.ensure_parent(path)
  local handle = fs.open(path, "w")
  if not handle then
    return nil, "cannot open " .. path
  end
  handle.write(data or "")
  handle.close()
  return true
end

function App.download(url, headers)
  if not http then
    return nil, "HTTP API is disabled"
  end
  local handle, err = http.get(url, headers or { ["Accept"] = "text/plain" })
  if not handle then
    return nil, err or "request failed"
  end
  local body = handle.readAll()
  local code = 200
  if handle.getResponseCode then
    code = handle.getResponseCode()
  end
  handle.close()
  if code < 200 or code >= 300 then
    return nil, "HTTP " .. tostring(code)
  end
  return body or ""
end

function App.run_hidden(callback)
  if window and term and term.current and term.redirect then
    local current = term.current()
    local hidden = window.create(current, 1, 1, 1, 1, false)
    term.redirect(hidden)
    local ok, result = pcall(callback)
    term.redirect(current)
    return ok, result
  end
  return pcall(callback)
end

function App.install_from_manifest(app)
  if not app or not app.installer then
    return nil, "invalid app manifest"
  end
  local body, err = App.download(app.installer)
  if not body then
    return nil, err
  end
  local installer_path = "/tmp/" .. tostring(app.id or "app") .. "-installer.lua"
  local ok, write_err = App.write_file(installer_path, body)
  if not ok then
    return nil, write_err
  end
  local run_ok, run_err = App.run_hidden(function()
    if shell then
      if app.source then
        return shell.run(installer_path, "--source", app.source)
      end
      return shell.run(installer_path)
    end
    return dofile(installer_path)
  end)
  if not run_ok then
    return nil, run_err
  end
  return true
end

function App.start(command, ...)
  if not shell then
    return nil, "shell API is unavailable"
  end
  return shell.run(command, ...)
end

return App
