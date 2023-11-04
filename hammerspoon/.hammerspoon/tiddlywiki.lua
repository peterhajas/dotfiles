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
    webView:evaluateJavaScript("document.body.style.zoom = 0.8")
    hs.timer.doAfter(60, update)
end

local function layout()
    local screen = hs.screen.primaryScreen()
    local rect = hs.geometry.rect(0,20,198,screen:frame().h - 20)
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

    layout()
    update()
end

setupWebView()
