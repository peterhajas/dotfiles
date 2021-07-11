
local preferences = {
    ['privateBrowsing'] = true
}

local backgroundWebView = hs.webview.new(hs.geometry.rect(0,0,0,0), preferences)

function updateBackgroundForScreens()
    local frame = hs.screen.mainScreen():fullFrame()
    backgroundWebView:frame(frame)
    :level(hs.canvas.windowLevels.desktopIcon - 1)
    :windowStyle({'nonactivating'})
    :behavior(hs.drawing.windowBehaviors.stationary)
    :allowMagnificationGestures(false)
    :allowNewWindows(false)
    :allowTextEntry(false)
    :url("http://localhost:9000")
    :show()
end

updateBackgroundForScreens()

