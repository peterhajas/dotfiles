-- Bind hyper-space
hs.hotkey.bind(hyper, 'space', function()
    peekAtApp("TiddlyDesktop")
end)

local wikiDirectory = os.getenv("HOME") .. "/phajas-wiki/"
local wikiPath = wikiDirectory .. "phajas-wiki.html"
local webView = nil

local function update()
    hs.alert("TICK")
    webView:url("file://" .. wikiPath .. "#Heads%20Up%20Display")
    webView:reload()

    hs.timer.doAfter(5, update)
end

local function layout()
    local rect = hs.geometry.rect(0,1000,180,480)
    webView:frame(rect)
    update()
end

local function setupWebView()
    local rect = hs.geometry.rect(0,1000,180,480)
    webView = hs.webview.new(rect)
    webView:url("file://" .. wikiPath .. "#Heads%20Up%20Display")
    webView:behavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
    webView:show()

    layout()
    hs.timer.doAfter(1, update)
end

-- setupWebView()
