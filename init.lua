-- mac-like-windows
-- Membuat macOS terasa seperti Windows, memakai Hammerspoon (https://www.hammerspoon.org).
-- Makes macOS behave more like Windows, using Hammerspoon.
--
-- Features / Fitur:
--   1. Click the active app's Dock icon to hide it; click again to show it.
--   2. Per-window switcher (Alt-Tab style): two Chrome windows are two entries.
--   3. Screenshots are copied to the clipboard as well as saved.
--   4. Finder keys: Enter opens, F2 renames, Delete trashes, Cut/Paste moves files.
--   5. Show desktop (Win + D) and open Finder (Win + R / Win + E).
--   6. Snap windows to the left/right half, maximize and restore (Win + arrows).
--   7. The green window button maximizes instead of entering full screen.
--
-- Everything is idle until a key or click triggers it.

------------------------------------------------------------------------------
-- CONFIGURATION / PENGATURAN
------------------------------------------------------------------------------
local config = {
  -- Hammerspoon itself
  launchAtLogin = true,
  hideMenuIcon  = true,
  hideDockIcon  = true,

  -- 1. Dock: click the frontmost app's icon to hide it
  dockClickToHide = true,

  -- 2. Window switcher. "cmd" replaces the built-in Command-Tab app switcher;
  --    use "alt" for Option-Tab and keep the built-in one.
  --    While the panel is open: Tab / Shift-Tab or Left / Right move, a mouse click
  --    selects, W closes the window, Q quits its app, H hides its app, Escape cancels.
  switcher = {
    enabled   = true,
    modifier  = "cmd",
    iconSize  = 96,
    showAllTitles = true,   -- false: only the selected window's title, like macOS
    extraKeys = true,       -- arrows, mouse click, W, Q, H
  },

  -- 3. Copy every new screenshot to the clipboard.
  --    folder = nil follows the macOS screenshot location (default: Desktop).
  screenshotToClipboard = true,
  screenshotFolder      = nil,

  -- 4. Finder keys (only while the file list is focused, never while typing)
  finder = {
    enterOpens    = true,   -- Enter opens (macOS default: rename)
    f2Renames     = true,   -- F2 renames
    deleteTrashes = true,   -- Delete moves to Trash (macOS default: Command-Delete)
    cutPaste      = true,   -- Command-X then Command-V moves files
  },

  -- 5. Global shortcuts. The Option key sits where the Windows key is.
  --    Set a shortcut to nil to disable it.
  showDesktop = { mods = { "alt" }, key = "d" },   -- Win + D
  openFinder  = { mods = { "alt" }, key = "r" },   -- Win + R (use "e" for Win + E)

  -- 6. Snap windows (Win + arrows). Left / Right = half screen, Up = maximize,
  --    Down = restore the previous size, or minimize if there is nothing to restore.
  --    Option-arrows already move by word in text, so the default adds Control.
  snap = { enabled = true, mods = { "ctrl", "alt" } },

  -- 7. The green window button maximizes (and restores) instead of full screen.
  --    Hold any modifier key while clicking to get the normal macOS behaviour.
  greenButtonMaximizes = true,

  -- Apps where the global shortcuts are passed through untouched.
  -- Useful if you bind them to Control (e.g. Control-D / Control-R in a terminal).
  -- Example: { "com.apple.Terminal", "com.microsoft.VSCode", "com.googlecode.iterm2" }
  shortcutExcludedApps = {},
}

------------------------------------------------------------------------------
-- SETUP
------------------------------------------------------------------------------
require("hs.ipc")
hs.autoLaunch(config.launchAtLogin)
hs.menuIcon(not config.hideMenuIcon)
hs.dockIcon(not config.hideDockIcon)
hs.window.animationDuration = 0

local ax    = require("hs.axuielement")
local types = hs.eventtap.event.types
local keys  = hs.keycodes.map

-- Every event tap we create, so the watchdog can revive one macOS has disabled.
local taps = {}

-- Frames saved before a window is maximized or snapped, keyed by window id,
-- so it can be restored. Shared by the snap shortcuts and the green button.
local savedFrames = {}

local function isMaximized(win)
  local f, s = win:frame(), win:screen():frame()
  return math.abs(f.x - s.x) < 6 and math.abs(f.y - s.y) < 6
     and math.abs(f.w - s.w) < 6 and math.abs(f.h - s.h) < 6
end

local function rememberFrame(win)
  local id = win:id()
  if id and not savedFrames[id] then savedFrames[id] = win:frame() end
end

-- Returns true if a saved frame was restored.
local function restoreFrame(win)
  local id = win:id()
  local f = id and savedFrames[id]
  if not f then return false end
  savedFrames[id] = nil
  win:setFrame(f)
  return true
end

local function toggleMaximize(win)
  if isMaximized(win) then
    if not restoreFrame(win) then
      local s = win:screen():frame()
      win:setFrame({ x = s.x + s.w * 0.15, y = s.y + s.h * 0.1, w = s.w * 0.7, h = s.h * 0.8 })
    end
  else
    rememberFrame(win)
    win:maximize()
  end
end

------------------------------------------------------------------------------
-- 1 & 7. MOUSE: Dock icon click hides the frontmost app; green button maximizes
------------------------------------------------------------------------------
if config.dockClickToHide or config.greenButtonMaximizes then
  local function elementUnderMouse()
    local pos = hs.mouse.absolutePosition()
    local ok, el = pcall(function()
      return ax.systemWideElement():elementAtPosition(pos.x, pos.y)
    end)
    if ok then return el end
    return nil
  end

  -- Title and app path of a Dock item element.
  local function dockItemInfo(el)
    local url = el:attributeValue("AXURL")
    local path = nil
    if type(url) == "table" then
      path = url.filePath or url.url
    elseif type(url) == "string" then
      path = url
    end
    if path then
      path = path:gsub("^file://", ""):gsub("%%20", " "):gsub("/$", "")
    end
    return { title = el:attributeValue("AXTitle"), path = path }
  end

  local function isFrontApp(item, app)
    if not app then return false end
    local appPath = app:path()
    if item.path and appPath and item.path == appPath:gsub("/$", "") then return true end
    return item.title ~= nil and item.title == app:name()
  end

  -- The window that owns a title-bar button element.
  local function windowOfButton(el)
    local ok, win = pcall(function()
      local axWin = el:attributeValue("AXWindow")
      return axWin and axWin:asHSWindow()
    end)
    if ok then return win end
    return nil
  end

  local swallowUp = false

  MouseTap = hs.eventtap.new({ types.leftMouseDown, types.leftMouseUp }, function(e)
    if e:getType() == types.leftMouseUp then
      if swallowUp then
        swallowUp = false
        return true
      end
      return false
    end

    local f = e:getFlags()
    if f.cmd or f.alt or f.ctrl or f.shift then return false end

    local el = elementUnderMouse()
    if not el then return false end
    local subrole = el:attributeValue("AXSubrole")

    if config.dockClickToHide and subrole == "AXApplicationDockItem" then
      local front = hs.application.frontmostApplication()
      if not isFrontApp(dockItemInfo(el), front) then return false end
      if #front:visibleWindows() == 0 then return false end
      front:hide()
      swallowUp = true
      return true
    end

    if config.greenButtonMaximizes
       and (subrole == "AXFullScreenButton" or subrole == "AXZoomButton") then
      local win = windowOfButton(el)
      if not win or win:isFullScreen() then return false end
      toggleMaximize(win)
      swallowUp = true
      return true
    end

    return false
  end)
  MouseTap:start()
  taps[#taps + 1] = MouseTap
end

------------------------------------------------------------------------------
-- 2. WINDOW SWITCHER (Alt-Tab style, one entry per window)
--    Hold the modifier, press Tab to go forward, Shift-Tab to go back,
--    release the modifier to select, Escape to cancel.
--    With extraKeys: Left / Right move, a click selects, W closes the window,
--    Q quits its app, H hides its app.
------------------------------------------------------------------------------
if config.switcher.enabled then
  local mod = config.switcher.modifier
  local sw  = { wins = nil, idx = 1, canvas = nil, layout = nil }
  local commit   -- defined below; the panel's click handler needs it

  local function collectWindows()
    local out, seen = {}, {}
    local function add(w)
      if w and w:isStandard() and not seen[w:id()] then
        seen[w:id()] = true
        out[#out + 1] = w
      end
    end
    for _, w in ipairs(hs.window.orderedWindows()) do add(w) end
    for _, w in ipairs(hs.window.minimizedWindows()) do add(w) end
    for _, app in ipairs(hs.application.runningApplications()) do
      if app:kind() == 1 and app:isHidden() then
        for _, w in ipairs(app:allWindows()) do add(w) end
      end
    end
    return out
  end

  local function closePanel()
    if sw.canvas then sw.canvas:delete() sw.canvas = nil end
    sw.wins = nil
    sw.layout = nil
  end

  local function titleOf(win)
    local t = win:title() or ""
    if t == "" then
      local app = win:application()
      t = app and app:name() or ""
    end
    return t
  end

  -- Looks like the built-in Command-Tab: large icons on a rounded translucent
  -- panel with a rounded highlight. Titles are shown under every icon, or only
  -- for the selected window when showAllTitles is false.
  local function draw()
    if sw.canvas then sw.canvas:delete() sw.canvas = nil end
    local n = #sw.wins
    if n == 0 then return end
    local allTitles = config.switcher.showAllTitles
    local icon, gap, pad, label = config.switcher.iconSize, 14, 18, 20
    local cell = icon + gap
    local rowH = icon + gap + (allTitles and label or 0)
    local screen = hs.screen.mainScreen():frame()
    local perRow = math.max(1, math.min(n, math.floor((screen.w - 160) / cell)))
    local rows = math.ceil(n / perRow)
    local w = perRow * cell + pad * 2
    local h = rows * rowH + pad * 2 + (allTitles and 0 or label + 2)
    local c = hs.canvas.new({ x = screen.x + (screen.w - w) / 2, y = screen.y + (screen.h - h) / 2, w = w, h = h })
    c:level(hs.canvas.windowLevels.overlay)
    c[#c + 1] = { type = "rectangle", action = "strokeAndFill",
                  fillColor = { red = 0.16, green = 0.16, blue = 0.17, alpha = 0.78 },
                  strokeColor = { white = 1, alpha = 0.12 }, strokeWidth = 1,
                  roundedRectRadii = { xRadius = 26, yRadius = 26 } }
    for i, win in ipairs(sw.wins) do
      local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
      local x, y = pad + col * cell, pad + row * rowH
      local selected = (i == sw.idx)
      local app = win:application()
      if selected then
        c[#c + 1] = { type = "rectangle", action = "fill", frame = { x = x + 1, y = y + 1, w = cell - 2, h = rowH - 2 },
                      fillColor = { white = 1, alpha = 0.18 },
                      roundedRectRadii = { xRadius = 18, yRadius = 18 } }
      end
      local img = app and app:bundleID() and hs.image.imageFromAppBundle(app:bundleID())
      if img then
        c[#c + 1] = { type = "image", image = img, frame = { x = x + gap / 2, y = y + gap / 2, w = icon, h = icon } }
      end
      if allTitles then
        c[#c + 1] = { type = "text", text = titleOf(win), textSize = 11,
                      textColor = { white = 1, alpha = selected and 1 or 0.7 },
                      textAlignment = "center", textLineBreak = "truncateTail",
                      frame = { x = x + 5, y = y + gap / 2 + icon + 1, w = cell - 10, h = label - 2 } }
      end
    end
    if not allTitles and sw.wins[sw.idx] then
      c[#c + 1] = { type = "text", text = titleOf(sw.wins[sw.idx]), textSize = 13,
                    textColor = { white = 1, alpha = 0.95 },
                    textAlignment = "center", textLineBreak = "truncateTail",
                    frame = { x = pad, y = h - pad - label + 4, w = w - pad * 2, h = label + 2 } }
    end
    sw.layout = { pad = pad, cell = cell, rowH = rowH, perRow = perRow }
    if config.switcher.extraKeys then
      c:canvasMouseEvents(true, false, false, false)
      c:mouseCallback(function(_, message, _, mx, my)
        if message ~= "mouseDown" or not sw.wins or not sw.layout then return end
        local L = sw.layout
        local col = math.floor((mx - L.pad) / L.cell)
        local row = math.floor((my - L.pad) / L.rowH)
        if col < 0 or col >= L.perRow or row < 0 then return end
        local i = row * L.perRow + col + 1
        if sw.wins[i] then
          sw.idx = i
          commit()
        end
      end)
    end
    c:show()
    sw.canvas = c
  end

  commit = function()
    local win = sw.wins and sw.wins[sw.idx]
    closePanel()
    if not win then return end
    local app = win:application()
    if app and app:isHidden() then app:unhide() end
    if win:isMinimized() then win:unminimize() end
    win:focus()
  end

  -- Safety net: if the modifier release is missed, close the panel and select.
  -- Runs only while the panel is open.
  SwitcherPoll = hs.timer.new(0.15, function()
    if not sw.wins then SwitcherPoll:stop() return end
    if not hs.eventtap.checkKeyboardModifiers()[mod] then commit() end
  end)

  local function step(dir)
    if not sw.wins then
      sw.wins = collectWindows()
      sw.idx = 1
      if #sw.wins == 0 then sw.wins = nil return end
    end
    sw.idx = ((sw.idx - 1 + dir) % #sw.wins) + 1
    draw()
    if not SwitcherPoll:running() then SwitcherPoll:start() end
  end

  -- Drops entries from the list (after closing a window or quitting an app)
  -- and redraws, or closes the panel when nothing is left.
  local function removeEntries(shouldRemove)
    local kept = {}
    for _, w in ipairs(sw.wins) do
      if not shouldRemove(w) then kept[#kept + 1] = w end
    end
    if #kept == 0 then closePanel() return end
    sw.wins = kept
    if sw.idx > #kept then sw.idx = #kept end
    draw()
  end

  -- Keys that act on the selected entry while the panel is open.
  local function handlePanelKey(code)
    local win = sw.wins[sw.idx]
    if code == keys["left"] then
      step(-1)
    elseif code == keys["right"] then
      step(1)
    elseif code == keys["w"] then
      if win then
        win:close()
        removeEntries(function(w) return w == win end)
      end
    elseif code == keys["q"] then
      local app = win and win:application()
      if app then
        local pid = app:pid()
        app:kill()
        removeEntries(function(w)
          local a = w:application()
          return a == nil or a:pid() == pid
        end)
      end
    elseif code == keys["h"] then
      local app = win and win:application()
      if app then app:hide() end
    else
      return false
    end
    return true
  end

  local function onlySwitcherMod(f)
    for _, m in ipairs({ "cmd", "ctrl", "alt" }) do
      if (f[m] or false) ~= (m == mod) then return false end
    end
    return true
  end

  SwitcherTap = hs.eventtap.new({ types.keyDown, types.flagsChanged }, function(e)
    local f = e:getFlags()
    if e:getType() == types.flagsChanged then
      if sw.wins and not f[mod] then commit() end
      return false
    end
    if e:getKeyCode() == keys["tab"] and onlySwitcherMod(f) then
      step(f.shift and -1 or 1)
      return true
    end
    if sw.wins and e:getKeyCode() == keys["escape"] then
      closePanel()
      return true
    end
    if sw.wins and config.switcher.extraKeys and f[mod] then
      return handlePanelKey(e:getKeyCode())
    end
    return false
  end)
  SwitcherTap:start()
  taps[#taps + 1] = SwitcherTap
end

------------------------------------------------------------------------------
-- 3. SCREENSHOTS: copy each new screenshot to the clipboard
------------------------------------------------------------------------------
if config.screenshotToClipboard then
  local function screenshotFolder()
    if config.screenshotFolder then
      return (config.screenshotFolder:gsub("^~", os.getenv("HOME")))
    end
    local out = hs.execute("/usr/bin/defaults read com.apple.screencapture location 2>/dev/null")
    out = out and out:gsub("%s+$", "") or ""
    if out ~= "" then return (out:gsub("^~", os.getenv("HOME"))) end
    return os.getenv("HOME") .. "/Desktop"
  end

  local shotDir  = screenshotFolder()
  local lastShot = nil

  if hs.fs.attributes(shotDir) then
    ScreenshotWatcher = hs.pathwatcher.new(shotDir, function(paths)
      for _, p in ipairs(paths) do
        local name  = p:match("([^/]+)$") or ""
        local lower = name:lower()
        if name:sub(1, 1) ~= "." and (lower:match("%.png$") or lower:match("%.jpe?g$"))
           and p ~= lastShot and hs.fs.attributes(p) then
          local img = hs.image.imageFromPath(p)
          if img then
            hs.pasteboard.writeObjects(img)
            lastShot = p
          end
        end
      end
    end)
    ScreenshotWatcher:start()
  end
end

------------------------------------------------------------------------------
-- 6. SNAP WINDOWS (Win + arrows)
------------------------------------------------------------------------------
-- Maps an arrow key name to the action for the focused window.
local snapActions = {
  left  = function(win) rememberFrame(win) win:moveToUnit({ x = 0,   y = 0, w = 0.5, h = 1 }) end,
  right = function(win) rememberFrame(win) win:moveToUnit({ x = 0.5, y = 0, w = 0.5, h = 1 }) end,
  up    = function(win)
    if not isMaximized(win) then
      rememberFrame(win)
      win:maximize()
    end
  end,
  down  = function(win)
    if not restoreFrame(win) then win:minimize() end
  end,
}

------------------------------------------------------------------------------
-- 4, 5 & 6. FINDER KEYS, GLOBAL SHORTCUTS AND SNAP KEYS
------------------------------------------------------------------------------
do
  local userData = hs.eventtap.event.properties.eventSourceUserData
  local MAGIC    = 0xC1A0DE   -- marks events we post ourselves, so we ignore them
  local typingRoles = { AXTextField = true, AXTextArea = true, AXComboBox = true, AXSearchField = true }
  local cutPending  = false

  local excluded = {}
  for _, id in ipairs(config.shortcutExcludedApps) do excluded[id] = true end

  local function send(mods, key)
    for _, down in ipairs({ true, false }) do
      local ev = hs.eventtap.event.newKeyEvent(mods, key, down)
      ev:setProperty(userData, MAGIC)
      ev:post()
    end
  end

  -- True when Finder's file list has focus: not while renaming, searching or in a dialog.
  local function finderListFocused()
    local app = hs.application.frontmostApplication()
    if not app or app:bundleID() ~= "com.apple.finder" then return false end
    local win = hs.window.focusedWindow()
    if win and win:subrole() ~= "AXStandardWindow" then return false end
    local ok, el = pcall(function()
      return ax.systemWideElement():attributeValue("AXFocusedUIElement")
    end)
    if not ok or not el then return false end
    local role = el:attributeValue("AXRole")
    if not role or typingRoles[role] or role == "AXButton" then return false end
    return true
  end

  -- True when exactly the modifiers in `mods` are held.
  local function modsMatch(f, mods)
    local want = {}
    for _, m in ipairs(mods or {}) do want[m] = true end
    for _, m in ipairs({ "cmd", "ctrl", "alt", "shift" }) do
      if (f[m] or false) ~= (want[m] or false) then return false end
    end
    return true
  end

  local function shortcutHit(sc, f, code)
    return sc ~= nil and code == keys[sc.key] and modsMatch(f, sc.mods)
  end

  local fk = config.finder

  WinKeysTap = hs.eventtap.new({ types.keyDown }, function(e)
    if e:getProperty(userData) == MAGIC then return false end
    local code = e:getKeyCode()
    local f    = e:getFlags()

    -- Global shortcuts: show desktop / open Finder
    local desktop = shortcutHit(config.showDesktop, f, code)
    local finder  = shortcutHit(config.openFinder, f, code)
    if desktop or finder then
      local app = hs.application.frontmostApplication()
      if app and excluded[app:bundleID() or ""] then return false end
      if desktop then
        hs.spaces.toggleShowDesktop()
      else
        hs.open(os.getenv("HOME"))
      end
      return true
    end

    -- Snap the focused window with the arrow keys
    if config.snap.enabled and modsMatch(f, config.snap.mods) then
      for name, action in pairs(snapActions) do
        if code == keys[name] then
          local win = hs.window.focusedWindow()
          if win and win:isStandard() and not win:isFullScreen() then action(win) end
          return true
        end
      end
    end

    -- Unmodified keys in Finder
    if modsMatch(f, {}) then
      local isReturn = code == keys["return"] and fk.enterOpens
      local isF2     = code == keys["f2"] and fk.f2Renames
      local isDelete = (code == keys["delete"] or code == keys["forwarddelete"]) and fk.deleteTrashes
      if isReturn or isF2 or isDelete then
        if not finderListFocused() then return false end
        if isReturn then
          send({ "cmd" }, "o")
        elseif isF2 then
          send({}, "return")
        else
          send({ "cmd" }, "delete")
        end
        return true
      end
    end

    -- Cut / paste files in Finder
    if fk.cutPaste and modsMatch(f, { "cmd" })
       and (code == keys["x"] or code == keys["c"] or code == keys["v"]) then
      if not finderListFocused() then return false end
      if code == keys["x"] then
        cutPending = true
        send({ "cmd" }, "c")
        return true
      elseif code == keys["c"] then
        cutPending = false
        return false
      elseif cutPending then
        cutPending = false
        send({ "cmd", "alt" }, "v")
        return true
      end
    end

    return false
  end)
  WinKeysTap:start()
  taps[#taps + 1] = WinKeysTap
end

------------------------------------------------------------------------------
-- WATCHDOG: macOS sometimes disables event taps; turn them back on.
------------------------------------------------------------------------------
TapWatchdog = hs.timer.doEvery(10, function()
  for _, tap in ipairs(taps) do
    if not tap:isEnabled() then tap:start() end
  end
end)
