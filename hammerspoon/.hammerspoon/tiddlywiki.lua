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

local wikiDirectory = os.getenv("HOME") .. "/phajas-wiki/"
WikiPath = wikiDirectory .. "phajas-wiki.html"
local hudStylesheetPath = os.getenv("HOME") .. "/dotfiles/userscripts/colorscheme.css"
local cachedWikiContents = ""
local cachedHudStylesheet = ""
local wikiStates = {}

local function readFile(path)
    local handle = io.open(path, "r")
    if handle == nil then
        return nil
    end
    local contents = handle:read("*a")
    handle:close()
    return contents
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
    local contents = cachedWikiContents
    local tiddler = wikiState['tiddler']
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

local function updateAllIfNeeded()
    for _, wikiState in ipairs(wikiStates) do
        if wikiState['needsUpdate'] then
            updateWikiState(wikiState)
            wikiState['needsUpdate'] = false
        end
    end
end

local function update()
    local wikiContents = readFile(WikiPath)
    if wikiContents ~= nil and wikiContents ~= cachedWikiContents then
        cachedWikiContents = wikiContents
        setNeedsUpdate()
    end
    local stylesheetContents = readFile(hudStylesheetPath) or ""
    -- Remove background override for HUD to preserve transparent/custom backgrounds
    stylesheetContents = stylesheetContents:gsub("background: var%(%-%-cs%-bg%) !important;", "")
    if stylesheetContents ~= cachedHudStylesheet then
        cachedHudStylesheet = stylesheetContents
        setNeedsUpdate()
    end
    updateAllIfNeeded()
end

local function displayForWikiState(wikiState)
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

local function layoutWikiState(wikiState)
    local display = displayForWikiState(wikiState)
    local webView = wikiState['webView']
    if display ~= nil then
        local screenFrame = display:frame()
        local topPadding = yOffset + journalOffset
        -- This lets us just match the right sidebar's frame (for now)
        -- to use less memory for the webview
        local hudWidth = 192  -- Match journal window width
        local hudFrame = {
            x = screenFrame.x + screenFrame.w - hudWidth,
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
    update()
    for _, wikiState in ipairs(wikiStates) do
        layoutWikiState(wikiState)
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
        setNeedsUpdate()
        update()
    end
end

local function screenCallback()
    setNeedsUpdate()
    layout()
end

WikiCaffeinateWatcher = hs.caffeinate.watcher.new(caffeinateCallback)
WikiScreenWatcher = hs.screen.watcher.new(screenCallback)
WikiPathWatcher = hs.pathwatcher.new(WikiPath, layout)

-- This is load-bearring and I don't know why
function UPDATEWIKI()
    layout()
end

local function registerColorsWatcher()
    local ok, colors = pcall(require, "colors")
    if ok and colors and colors.onColorsChanged then
        colors.onColorsChanged(function()
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

    screenCallback()
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

local port = 8045
WikiServer = nil
local function startWikiServer()
    WikiServer = hs.httpserver.hsminweb.new(os.getenv("HOME").."/phajas-wiki")
    :interface("localhost")
    :port(port)
    :start()
end

startWikiServer()
registerColorsWatcher()
setupWebView()
