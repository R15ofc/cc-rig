local UI = {}

UI.VERSION = "0.1.0"

UI.theme = {
  background = colors.black,
  surface = colors.gray,
  surface_dark = colors.black,
  topbar = colors.gray,
  sidebar = colors.gray,
  active = colors.cyan,
  text = colors.white,
  muted = colors.lightGray,
  success = colors.lime,
  warning = colors.orange,
  danger = colors.red,
  button = colors.blue,
}

function UI.can_color()
  return term and term.isColor and term.isColor()
end

function UI.set_fg(color)
  if UI.can_color() and color then
    term.setTextColor(color)
  end
end

function UI.set_bg(color)
  if UI.can_color() and color then
    term.setBackgroundColor(color)
  end
end

function UI.reset()
  if UI.can_color() then
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
  end
end

function UI.size()
  local width, height = term.getSize()
  return width or 51, height or 19
end

function UI.fit(text, width)
  text = tostring(text or "")
  if #text <= width then
    return text
  end
  if width <= 1 then
    return text:sub(1, width)
  end
  return text:sub(1, width - 1) .. "."
end

function UI.pad(text, width)
  text = UI.fit(text, width)
  return text .. string.rep(" ", math.max(0, width - #text))
end

function UI.clear(background)
  UI.reset()
  if background then
    UI.set_bg(background)
  end
  term.clear()
  term.setCursorPos(1, 1)
  UI.reset()
end

function UI.write_at(x, y, text, foreground, background)
  UI.set_fg(foreground)
  UI.set_bg(background)
  term.setCursorPos(x, y)
  term.write(tostring(text or ""))
  UI.reset()
end

function UI.fill(x, y, width, height, background)
  if width <= 0 or height <= 0 then
    return
  end
  UI.set_bg(background or UI.theme.background)
  for row = y, y + height - 1 do
    term.setCursorPos(x, row)
    term.write(string.rep(" ", width))
  end
  UI.reset()
end

function UI.new_screen(options)
  options = options or {}
  local screen = {
    theme = options.theme or UI.theme,
    hits = {},
  }

  function screen:reset_hits()
    self.hits = {}
  end

  function screen:hit(id, x, y, width, height, payload)
    if width <= 0 or height <= 0 then
      return
    end
    table.insert(self.hits, {
      id = id,
      x1 = x,
      y1 = y,
      x2 = x + width - 1,
      y2 = y + height - 1,
      payload = payload,
    })
  end

  function screen:hit_at(x, y)
    for index = #self.hits, 1, -1 do
      local hitbox = self.hits[index]
      if x >= hitbox.x1 and x <= hitbox.x2 and y >= hitbox.y1 and y <= hitbox.y2 then
        return hitbox
      end
    end
    return nil
  end

  function screen:topbar(title, right)
    local width = UI.size()
    UI.fill(1, 1, width, 1, self.theme.topbar)
    UI.write_at(2, 1, UI.fit(title or "", width - 4), self.theme.text, self.theme.topbar)
    if right and right ~= "" then
      UI.write_at(width - #right, 1, right, self.theme.muted, self.theme.topbar)
    end
  end

  function screen:button(id, x, y, label, payload, color)
    local width = #label + 4
    UI.fill(x, y, width, 2, color or self.theme.button)
    UI.write_at(x + 2, y, label, self.theme.text, color or self.theme.button)
    self:hit(id, x, y, width, 2, payload)
  end

  function screen:card(id, x, y, width, height, card)
    card = card or {}
    UI.fill(x + 1, y + 1, width, height, colors.black)
    UI.fill(x, y, width, height, card.background or self.theme.surface)
    UI.fill(x, y, width, 1, card.color or self.theme.active)
    UI.write_at(x + 1, y + 2, UI.fit(card.title or "", width - 2), self.theme.text, card.background or self.theme.surface)
    if card.subtitle then
      UI.write_at(x + 1, y + 3, UI.fit(card.subtitle, width - 2), self.theme.muted, card.background or self.theme.surface)
    end
    self:hit(id, x, y, width, height, card.payload)
  end

  function screen:modal(title, lines, buttons)
    local terminal_width, terminal_height = UI.size()
    local modal_width = math.min(terminal_width - 8, 40)
    local modal_height = 7 + #(lines or {})
    local x = math.floor((terminal_width - modal_width) / 2) + 1
    local y = math.floor((terminal_height - modal_height) / 2) + 1
    UI.fill(x + 1, y + 1, modal_width, modal_height, colors.black)
    UI.fill(x, y, modal_width, modal_height, self.theme.surface)
    UI.fill(x, y, modal_width, 1, self.theme.active)
    UI.write_at(x + 1, y, UI.fit(title or "", modal_width - 2), colors.black, self.theme.active)
    for index, line in ipairs(lines or {}) do
      UI.write_at(x + 2, y + 1 + index, UI.fit(line, modal_width - 4), self.theme.text, self.theme.surface)
    end
    local button_x = x + 2
    local button_y = y + modal_height - 2
    for _, button in ipairs(buttons or {}) do
      self:button(button.action, button_x, button_y, button.label, button.payload, button.color)
      button_x = button_x + #button.label + 8
    end
  end

  return screen
end

return UI
