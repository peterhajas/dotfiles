-- Rendering
function TiddlyWikiRender(name)
    local out, _, _, _ = hs.execute('~/bin/tiddlywiki_render ' .. name)
    return out
end

-- Metrics
local yOffset = 30

-- Bind hyper-space
hs.hotkey.bind(hyper, 'space', function()
    peekAtApp("TiddlyDesktop")
end)

local wikiDirectory = os.getenv("HOME") .. "/phajas-wiki/"
WikiPath = wikiDirectory .. "phajas-wiki.html"
local cachedWikiContents = ""

local wikiStates = {}

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
    local tiddlerStore = [[<script class="tiddlywiki-tiddler-store" type="application/json">[
{"title":"Heads Up Display Host","text":"{{ ]] .. tiddler .. [[}}"},
{"title":"Do It","text":"\\import $:/phajas/hud/actions\n\n\u003C\u003Cphajas_hud_actions>>","tags":"$:/tags/StartupAction/PostRender"}
]</script>
]]

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
    local wikiFile = io.open(WikiPath, "r")
    if wikiFile ~= nil then
        local wikiContents = wikiFile:read("*a")
        if wikiContents ~= cachedWikiContents then
            cachedWikiContents = wikiContents
            setNeedsUpdate()
        end
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
        webView:frame(screenFrame)
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

local function setupWebView()
    createWikiState("main", "Heads Up Display Desktop", "Primary")
    createWikiState("right", "Heads Up Display Right", "FP222W (2)")
    createWikiState("left", "Heads Up Display Left", "FP222W (1)")

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
setupWebView()
