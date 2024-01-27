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
local tiddler = "Desktop%20Demo"

local function update()
    webView:url({
        ["URL"] = "file://" .. wikiPath .. "#" .. tiddler,
        ["cachePolicy"] = {
            ["ignoreLocalCache"] = "true"
        }
    })
end

local function handleMachineWake(eventType)
    if eventType == hs.caffeinate.watcher.systemDidWake then
        update()
    end
end

local caffeinateWatcher = hs.caffeinate.watcher.new(handleMachineWake)

local function layout()
    local screen = hs.screen.primaryScreen()
    local rect = hs.geometry.rect(0,yOffset,width,screen:frame().h - yOffset)
    webView:frame(rect)
end

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
        update()
    end):start()

    layout()
    update()
end

setupWebView()
