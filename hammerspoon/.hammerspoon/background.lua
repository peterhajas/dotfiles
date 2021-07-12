
local preferences = {
    ['privateBrowsing'] = true
}

local backgroundWebView = hs.webview.new(hs.geometry.rect(0,0,0,0), preferences)

function updateBackgroundForScreens()
    local frame = hs.screen.mainScreen():fullFrame()

    backgroundWebView:frame(frame)
    :level(hs.canvas.windowLevels.desktopIcon)
    :windowStyle({'nonactivating'})
    :behavior(hs.drawing.windowBehaviors.stationary)
    :allowGestures(false)
    :allowNewWindows(false)
    :url("http://localhost:9000")
    :transparent(true)
    :show()
end

updateBackgroundForScreens()

