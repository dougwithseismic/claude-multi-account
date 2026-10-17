require("hs.ipc") -- lets the `hs` command line tool talk to Hammerspoon

-- Claude A / B / C: Claude desktop instances, one per account (A uses the normal
-- data folder, the others run with --user-data-dir=~/Library/Application Support/Claude-<letter>).
-- Shows which one is in front in the menu bar, outlines its window in that
-- account's colour, and switches with ⌥⌘1 / ⌥⌘2 / ⌥⌘3. Rename the labels to the
-- accounts' emails if you like. To add another, give it a line here and a launcher.
local PROFILES = {
  A = { label = "Claude A", color = { hex = "#2F7BF5" }, key = "1" },
  B = { label = "Claude B", color = { hex = "#F5822F" }, key = "2" },
  C = { label = "Claude C", color = { hex = "#2FB36B" }, key = "3" },
}
local ORDER = {}
for p in pairs(PROFILES) do table.insert(ORDER, p) end
table.sort(ORDER)
local BUNDLE = "com.anthropic.claudefordesktop"
local HOME = os.getenv("HOME")

claudeAB = { profileByPid = {} }
local S = claudeAB

local function profileOf(app)
  if not app or app:bundleID() ~= BUNDLE then return nil end
  local pid = app:pid()
  if S.profileByPid[pid] == nil then
    local cmd = hs.execute("ps -o command= -p " .. pid) or ""
    S.profileByPid[pid] = cmd:match("Application Support/Claude%-(%u)") or "A"
  end
  return S.profileByPid[pid]
end

local function runningApp(p)
  for _, app in ipairs(hs.application.applicationsForBundleID(BUNDLE)) do
    if profileOf(app) == p then return app end
  end
end

-- Closing the last window leaves Claude running with none. Send it the "reopen"
-- event a Dock click sends, which makes it open a new window.
local function reopen(app)
  hs.osascript.javascript(string.format([[
    ObjC.import('Foundation');
    var target = $.NSAppleEventDescriptor.descriptorWithProcessIdentifier(%d);
    $.NSAppleEventDescriptor.appleEventWithEventClassEventIDTargetDescriptorReturnIDTransactionID(0x61657674, 0x72617070, target, -1, 0).sendEventWithOptionsTimeoutError(1, 5, null);
  ]], app:pid()))
end

-- macOS sometimes ignores activating one of several copies of the same app, so
-- focus its window directly and try again until it is in front.
local function bringForward(app, tries)
  local win = app:mainWindow() or app:allWindows()[1]
  if win then win:focus() else reopen(app); app:activate(true) end
  if tries > 1 then
    hs.timer.doAfter(0.3, function()
      local front = hs.application.frontmostApplication()
      if not front or front:pid() ~= app:pid() then bringForward(app, tries - 1) end
    end)
  end
end

local function switchTo(p)
  local app = runningApp(p)
  if app then
    bringForward(app, 5)
  else
    hs.task.new(HOME .. "/Applications/Claude " .. p .. ".app/Contents/Resources/claude-profile.sh", nil, { p }):start()
  end
end

-- claude:// links -----------------------------------------------------------
-- macOS hands every claude:// link (sign-in callbacks included) to the first
-- Claude started. ~/Applications/Claude Link Router.app owns the scheme instead
-- and calls this, so a link goes to the Claude used last.

function S.openURL(url)
  local app = runningApp(S.last or "A")
  for _, p in ipairs(ORDER) do app = app or runningApp(p) end
  if not app then
    hs.execute("open -b " .. BUNDLE .. " '" .. url:gsub("'", "'\\''") .. "'")
    return "launched"
  end
  local ok, result = hs.osascript.javascript(string.format([[
    ObjC.import('Foundation');
    var target = $.NSAppleEventDescriptor.descriptorWithProcessIdentifier(%d);
    var event = $.NSAppleEventDescriptor.appleEventWithEventClassEventIDTargetDescriptorReturnIDTransactionID(0x4755524C, 0x4755524C, target, -1, 0);
    event.setParamDescriptorForKeyword($.NSAppleEventDescriptor.descriptorWithString(%q), 0x2D2D2D2D);
    var error = Ref();
    event.sendEventWithOptionsTimeoutError(1, 10, error) ? 'sent' : ('failed: ' + ObjC.unwrap(error[0].localizedDescription));
  ]], app:pid(), url))
  app:activate(true)
  return ok and result or ("failed: " .. hs.inspect(result))
end

-- Menu bar ------------------------------------------------------------------

S.bar = hs.menubar.new()

local function setBar(p, active)
  if not p then
    S.bar:setTitle("Claude")
    return
  end
  local cfg = PROFILES[p]
  S.bar:setTitle(hs.styledtext.new((active and "● " or "○ ") .. cfg.label, {
    color = active and cfg.color or { white = 0.55 },
    font = { name = "Menlo-Bold", size = 12 },
  }))
end

S.bar:setMenu(function()
  local items = {}
  for _, p in ipairs(ORDER) do
    local cfg = PROFILES[p]
    table.insert(items, {
      title = "Switch to " .. cfg.label .. "  (⌥⌘" .. cfg.key .. ")",
      checked = S.last == p,
      fn = function() switchTo(p) end,
    })
  end
  return items
end)

-- Window border -------------------------------------------------------------

local function hideBorder()
  if S.border then
    S.border:delete()
    S.border = nil
  end
end

local function drawBorder(win)
  hideBorder()
  if not win or not win:isStandard() or win:isFullScreen() then return end
  local p = profileOf(win:application())
  if not p then return end
  local f, pad, width = win:frame(), 3, 4
  S.border = hs.canvas.new({ x = f.x - pad, y = f.y - pad, w = f.w + pad * 2, h = f.h + pad * 2 })
  S.border:appendElements({
    type = "rectangle",
    action = "stroke",
    strokeColor = PROFILES[p].color,
    strokeWidth = width,
    roundedRectRadii = { xRadius = 14, yRadius = 14 },
    frame = { x = width / 2, y = width / 2, w = f.w + pad * 2 - width, h = f.h + pad * 2 - width },
  })
  S.border:level(hs.canvas.windowLevels.floating)
  S.border:show()
end

local function refresh()
  local front = hs.application.frontmostApplication()
  local p = profileOf(front)
  if p then S.last = p end
  setBar(S.last, p ~= nil)
  if p then drawBorder(hs.window.focusedWindow()) else hideBorder() end
end

-- Watchers and hotkeys ------------------------------------------------------

-- A Claude update may register itself for claude:// again; take it back.
local ROUTER = "com.godzillaaa.claude-link-router"
local function claimLinks()
  if hs.application.pathForBundleID(ROUTER) and hs.urlevent.getDefaultHandler("claude") ~= ROUTER then
    hs.urlevent.setDefaultHandler("claude", ROUTER)
  end
end
claimLinks()

S.apps = hs.application.watcher.new(function(_, event, app)
  if event == hs.application.watcher.launched and app and app:bundleID() == BUNDLE then
    hs.timer.doAfter(5, claimLinks)
  end
  if event == hs.application.watcher.activated or event == hs.application.watcher.deactivated
    or event == hs.application.watcher.terminated then
    refresh()
  end
end)
S.apps:start()

S.windows = hs.window.filter.new(function(win)
  return win:application() and win:application():bundleID() == BUNDLE
end)
S.windows:subscribe({
  hs.window.filter.windowFocused,
  hs.window.filter.windowMoved,
  hs.window.filter.windowUnfocused,
  hs.window.filter.windowDestroyed,
  hs.window.filter.windowMinimized,
  hs.window.filter.windowFullscreened,
  hs.window.filter.windowUnfullscreened,
}, refresh)

for p, cfg in pairs(PROFILES) do
  hs.hotkey.bind({ "alt", "cmd" }, cfg.key, function() switchTo(p) end)
end

refresh()
