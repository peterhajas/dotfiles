-- Metrics

local width = 180
local yOffset = 30

-- Bind hyper-space
hs.hotkey.bind(hyper, 'space', function()
    peekAtApp("TiddlyDesktop")
end)

local wikiDirectory = os.getenv("HOME") .. "/phajas-wiki/"
local wikiPath = wikiDirectory .. "phajas-wiki.html"
local webView = nil

local function update()
    local wikiFile = io.open(wikiPath, "r")
    if wikiFile ~= nil then
        local wikiContents = wikiFile:read("*a")
        wikiContents = string.gsub(wikiContents, "SHOWHUDNO", "SHOWHUDYES_SIDEBARWIDGET")
        wikiContents = string.gsub(wikiContents, "#2d2d2d", "unset")
        webView:html(wikiContents)
    end
end

local function layout()
    update()
    local screen = hs.screen.primaryScreen()
    local rect = hs.geometry.rect(0,yOffset,width,screen:frame().h - yOffset)
    webView:frame(rect)
end

local function handleCaffeineCallback(eventType)
    layout()
end

local caffeinateWatcher = hs.caffeinate.watcher.new(handleCaffeineCallback)
local wikiScreenWatcher = hs.screen.watcher.new(layout)

local function setupWebView()
    local rect = hs.geometry.rect(0,0,0,0)
    webView = hs.webview.new(rect)
    webView:behavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
    webView:transparent(true)
    webView:sendToBack()
    webView:show()
    wikiScreenWatcher:start()
    caffeinateWatcher:start()

    hs.pathwatcher.new(wikiPath, function()
        layout()
    end):start()

    layout()
    update()
end

setupWebView()
