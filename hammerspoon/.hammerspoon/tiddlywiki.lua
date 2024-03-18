-- Metrics

local width = 180
local yOffset = 30

-- Bind hyper-space
hs.hotkey.bind(hyper, 'space', function()
    peekAtApp("TiddlyDesktop")
end)

local wikiDirectory = os.getenv("HOME") .. "/phajas-wiki/"
WikiPath = wikiDirectory .. "phajas-wiki.html"
local webView = nil

local function update()
    local wikiFile = io.open(WikiPath, "r")
    if wikiFile ~= nil then
        local wikiContents = wikiFile:read("*a")
        wikiContents = string.gsub(wikiContents, "HUDNONE", "Heads Up Display Desktop")
        wikiContents = string.gsub(wikiContents, "HUDOPTIONSNONE", "HUDOPTIONS_SIDEBARWIDGET")
        wikiContents = string.gsub(wikiContents, "#2d2d2d", "#2d2d2d99")
        webView:html(wikiContents)
    end
end

local function layout()
    update()
    local screen = hs.screen.primaryScreen()
    local rect = hs.geometry.rect(0,yOffset,width,screen:frame().h - yOffset)
    webView:frame(rect)
end

WikiCaffeinateWatcher = hs.caffeinate.watcher.new(layout)
WikiScreenWatcher = hs.screen.watcher.new(layout)
WikiPathWatcher = hs.pathwatcher.new(WikiPath, layout)

-- This is load-bearring and I don't know why
function UPDATEWIKI()
    layout()
end

local function setupWebView()
    local rect = hs.geometry.rect(0,0,0,0)
    webView = hs.webview.new(rect)
    webView:behavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
    webView:transparent(true)
    webView:sendToBack()
    webView:show()

    WikiScreenWatcher:start()
    WikiCaffeinateWatcher:start()
    WikiPathWatcher:start()

    layout()
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

setupWebView()
