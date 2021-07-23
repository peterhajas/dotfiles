require "util"

-- plh-evil: multiple displays?
local sharedWebView = hs.webview.new(hs.geometry.rect(0,0,0,0))

function updateWebView(webView, screen)
    webView
    :frame(screen:frame())
    :allowGestures(false)
    :url('http://localhost:9000')
    :level(hs.drawing.windowLevels.desktopIcon-1)
    :transparent(true)
    :show()
end

function updateStickyVimwikiForScreens()
    updateWebView(sharedWebView, hs.screen.mainScreen())
end

updateStickyVimwikiForScreens()

