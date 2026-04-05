-- Rendering
function TiddlyWikiRender(name)
    -- Escape single quotes in name and wrap in single quotes for shell safety
    local escaped = name:gsub("'", "'\\''")
    local out, _, _, _ = hs.execute("~/bin/tiddlywiki_render '" .. escaped .. "'")
    return out
end

-- Metrics
local yOffset = -1
-- Journal offset calculation (ZERO gap between journal and HUD):
-- - Journal window: y=31 (menu bar accounts for offset), height=400
-- - Journal bottom: 31 + 400 = 431
-- - HUD should start at: 431 (zero gap)
-- - Since HUD y = yOffset + journalOffset = -1 + journalOffset, we need journalOffset = 432
local journalOffset = 432  -- Reserve space for journal window (zero gap)
local journalOffsetEnabled = true
local journalWindowTitleToken = "wiki_journal_today"
local journalOffsetActive = false

local wikiDirectory = os.getenv("HOME") .. "/phajas-wiki/"
WikiPath = wikiDirectory .. "phajas-wiki.html"
local hudStylesheetPath = os.getenv("HOME") .. "/dotfiles/userscripts/colorscheme.css"
local cachedWikiContents = ""
local cachedHudStylesheet = ""
local wikiStates = {}
local quickOpenPreviewHelpTitle = "$:/plugins/phajas/hud/QuickOpenPreviewHelp"
local wikiContentsDirty = true
local hudStylesheetDirty = true
local loadingHUDHTML = [[
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background: transparent;
      color: rgba(240, 244, 255, 0.9);
      font-family: Menlo, Monaco, monospace;
      font-size: 12px;
    }
    .loading {
      padding: 10px 8px;
      opacity: 0.8;
    }
  </style>
</head>
<body><div class="loading">HUD loading...</div></body>
</html>
]]

local function readFile(path)
    local handle = io.open(path, "r")
    if handle == nil then
        return nil
    end
    local contents = handle:read("*a")
    handle:close()
    return contents
end

local function jsQuote(value)
    if value == nil then
        return "''"
    end
    return "'" .. tostring(value)
        :gsub("\\", "\\\\")
        :gsub("'", "\\'")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        .. "'"
end

local function createWikiState(name, tiddler, displayName)
    local rect = hs.geometry.rect(0,0,0,0)
    local state = {
        ['name'] = name,
        ['webView'] = hs.webview.new(rect)
        :behavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
        :transparent(true)
        :allowTextEntry(true)
        :allowNewWindows(false)
        :level(hs.drawing.windowLevels.normal - 1)
        :html(loadingHUDHTML)
        :show(),
        ['needsUpdate'] = false,
        ['tiddler'] = tiddler,
        ['displayName'] = displayName,
    }
    table.insert(wikiStates, state)
end

local function setNeedsUpdate()
    for _, value in ipairs(wikiStates) do
        value['needsUpdate'] = true
    end
end

local function updateWikiState(wikiState)
    local tiddler = wikiState['tiddler']
    local contents = cachedWikiContents
    local tiddlers = {
        {
            title = "$:/plugins/phajas/hud/CurrentHUD",
            text = tiddler,
        },
    }
    if cachedHudStylesheet ~= "" then
        table.insert(tiddlers, {
            title = "$:/plugins/phajas/hud/ColorschemeStylesheet",
            type = "text/css",
            tags = "$:/tags/Stylesheet",
            text = cachedHudStylesheet,
        })
    end
    local tiddlerStore = [[<script class="tiddlywiki-tiddler-store" type="application/json">]]
        .. hs.json.encode(tiddlers)
        .. [[</script>]]

    local webViewContents = tiddlerStore .. contents
    local webView = wikiState['webView']
    webView:html(webViewContents)
end

local function buildHUDHTML(currentHUDTitle, previewHelpText)
    local tiddlers = {
        {
            title = "$:/plugins/phajas/hud/CurrentHUD",
            text = currentHUDTitle or "",
        },
    }

    if previewHelpText ~= nil then
        table.insert(tiddlers, {
            title = quickOpenPreviewHelpTitle,
            text = previewHelpText,
        })
    end

    if cachedHudStylesheet ~= "" then
        table.insert(tiddlers, {
            title = "$:/plugins/phajas/hud/ColorschemeStylesheet",
            type = "text/css",
            tags = "$:/tags/Stylesheet",
            text = cachedHudStylesheet,
        })
    end

    local tiddlerStore = [[<script class="tiddlywiki-tiddler-store" type="application/json">]]
        .. hs.json.encode(tiddlers)
        .. [[</script>]]

    return tiddlerStore .. cachedWikiContents
end

local function updateAllIfNeeded()
    for _, wikiState in ipairs(wikiStates) do
        if wikiState['needsUpdate'] then
            updateWikiState(wikiState)
            wikiState['needsUpdate'] = false
        end
    end
end

local function update()
    if wikiContentsDirty then
        local wikiContents = readFile(WikiPath)
        if wikiContents ~= nil and wikiContents ~= cachedWikiContents then
            cachedWikiContents = wikiContents
            setNeedsUpdate()
        end
        wikiContentsDirty = false
    end

    if hudStylesheetDirty then
        local stylesheetContents = readFile(hudStylesheetPath) or ""
        -- Remove background override for HUD to preserve transparent/custom backgrounds
        stylesheetContents = stylesheetContents:gsub("background: var%(%-%-cs%-bg%) !important;", "")
        if stylesheetContents ~= cachedHudStylesheet then
            cachedHudStylesheet = stylesheetContents
            setNeedsUpdate()
        end
        hudStylesheetDirty = false
    end

    updateAllIfNeeded()
end

-- Exposed for other Hammerspoon modules (e.g. quick-open preview)
function TiddlyWikiBuildHUDHTML(currentHUDTitle, previewHelpText)
    update()
    return buildHUDHTML(currentHUDTitle, previewHelpText)
end

-- Update CurrentHUD in an already-running webview without reloading full HTML
function TiddlyWikiUpdateHUDCurrent(webview, currentHUDTitle, previewHelpText)
    if webview == nil then
        return false
    end

    local script = [[
(function(currentHUD, helpTitle, helpText) {
  if (!window.$tw || !$tw.wiki || !window.$tw.Tiddler) { return false; }
  $tw.wiki.addTiddler(new $tw.Tiddler({title: "$:/plugins/phajas/hud/CurrentHUD", text: currentHUD}));
  if (helpText !== null) {
    $tw.wiki.addTiddler(new $tw.Tiddler({title: helpTitle, text: helpText}));
  }
  if ($tw.rootWidget && $tw.rootWidget.refresh) {
    var changed = {};
    changed["$:/plugins/phajas/hud/CurrentHUD"] = true;
    changed[helpTitle] = true;
    $tw.rootWidget.refresh(changed);
  }
  return true;
})(]] .. jsQuote(currentHUDTitle or "") .. [[, ]] .. jsQuote(quickOpenPreviewHelpTitle) .. [[, ]] .. (previewHelpText == nil and "null" or jsQuote(previewHelpText)) .. [[);
]]

    webview:evaluateJavaScript(script)
    return true
end

function TiddlyWikiQuickOpenHelpTitle()
    return quickOpenPreviewHelpTitle
end

local function rightmostScreen()
    local screens = hs.screen.allScreens()
    if #screens < 3 then
        return nil
    end
    local rightmost = nil
    local maxX = -math.huge
    for _, screen in ipairs(screens) do
        local frame = screen:frame()
        if frame.x > maxX then
            maxX = frame.x
            rightmost = screen
        end
    end
    return rightmost
end

local function displayForWikiState(wikiState)
    -- In 3+ display configs, use the rightmost screen
    local rm = rightmostScreen()
    if rm then
        return rm
    end
    if wikiState['displayName'] == "Primary" then
        return hs.screen.primaryScreen()
    end
    for _, screen in ipairs(hs.screen.allScreens()) do
        if screen:name() == wikiState['displayName'] then
            return screen
        end
    end
    return nil
end

local function journalWindowPresent()
    local ok, windows = pcall(hs.window.allWindows)
    if not ok then return false end
    for _, win in ipairs(windows) do
        local title = win:title() or ""
        if title:lower():find(journalWindowTitleToken, 1, true) then
            return true
        end
    end
    return false
end

local function currentJournalOffset()
    if journalOffsetEnabled and journalOffsetActive then
        return journalOffset
    end
    return 0
end

local function layoutWikiState(wikiState)
    local display = displayForWikiState(wikiState)
    local webView = wikiState['webView']
    if display ~= nil then
        local screenFrame = display:frame()
        local topPadding = yOffset + currentJournalOffset()
        local hudWidth = 192
        -- In 3+ display configs, HUD is on the far left of the rightmost display
        local useLeftEdge = rightmostScreen() ~= nil
        local hudX
        if useLeftEdge then
            hudX = screenFrame.x
        else
            hudX = screenFrame.x + screenFrame.w - hudWidth
        end
        local hudFrame = {
            x = hudX,
            y = screenFrame.y + topPadding,
            w = hudWidth,
            h = screenFrame.h - topPadding
        }
        webView:frame(hudFrame)
    else
        local rect = hs.geometry.rect(0,0,0,0)
        webView:frame(rect)
    end
end

local function layout()
    for _, wikiState in ipairs(wikiStates) do
        layoutWikiState(wikiState)
    end
end

local function refreshJournalOffset()
    local present = journalWindowPresent()
    if present ~= journalOffsetActive then
        journalOffsetActive = present
        layout()
    end
end

local function caffeinateCallback(event)
    layout()
    if event == hs.caffeinate.watcher.screensDidLock or event == hs.caffeinate.watcher.screensaverDidStart or event == hs.caffeinate.watcher.systemWillSleep then
        SaveWiki()
        local tiddlyApp = hs.application.find("TiddlyDesktop")
        if tiddlyApp ~= nil then
            tiddlyApp:kill()
        end
    elseif event == hs.caffeinate.watcher.screensDidUnlock then
        wikiContentsDirty = true
        hudStylesheetDirty = true
        setNeedsUpdate()
        update()
    end
end

local function screenCallback()
    layout()
end

WikiCaffeinateWatcher = hs.caffeinate.watcher.new(caffeinateCallback)
WikiScreenWatcher = hs.screen.watcher.new(screenCallback)
WikiPathWatcher = hs.pathwatcher.new(WikiPath, function()
    wikiContentsDirty = true
    setNeedsUpdate()
    update()
end)
local okWf, journalWf = pcall(hs.window.filter.new)
if okWf and journalWf then
    JournalWindowWatcher = journalWf:subscribe(
        {hs.window.filter.windowCreated, hs.window.filter.windowDestroyed, hs.window.filter.windowTitleChanged},
        function()
            refreshJournalOffset()
        end
    )
end

-- This is load-bearring and I don't know why
function UPDATEWIKI()
    wikiContentsDirty = true
    hudStylesheetDirty = true
    setNeedsUpdate()
    update()
    layout()
end

local function registerColorsWatcher()
    local ok, colors = pcall(require, "colors")
    if ok and colors and colors.onColorsChanged then
        colors.onColorsChanged(function()
            hudStylesheetDirty = true
            setNeedsUpdate()
            update()
        end)
    end
end

local function setupWebView()
    createWikiState("main", "Heads Up Display Desktop", "Primary")
    -- createWikiState("right", "Heads Up Display Right", "FP222W (2)")
    -- createWikiState("left", "Heads Up Display Left", "FP222W (1)")

    WikiScreenWatcher:start()
    WikiCaffeinateWatcher:start()
    WikiPathWatcher:start()
    refreshJournalOffset()

    screenCallback()
    setNeedsUpdate()
    update()
end

function SaveWiki()
    local app = hs.application.find("TiddlyDesktop")
    local down = hs.eventtap.event.newKeyEvent({"cmd"}, string.lower("s"), true)
    down:post(app)
    local up = hs.eventtap.event.newKeyEvent({"cmd"}, string.lower("s"), false)
    up:post(app)
end

wikiAppWatcher = hs.application.watcher.new(function(name, type, app)
    local leavingTiddlyDesktop = name == "TiddlyDesktop" and type == hs.application.watcher.deactivated 
    if leavingTiddlyDesktop then
        SaveWiki()
    end
end)
wikiAppWatcher:start()

WikiServer = nil
local function startWikiServer()
    WikiServer = hs.httpserver.hsminweb.new(os.getenv("HOME").."/phajas-wiki")
    :interface("localhost")
    :port(8045)
    :start()
end

startWikiServer()
registerColorsWatcher()
setupWebView()
