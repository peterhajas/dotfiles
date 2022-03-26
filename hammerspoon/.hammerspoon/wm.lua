local storage = { }
local module = { storage = storage }

local function centerMouseOnFocusedWindow()
    local focusedWindowFrame = hs.window.focusedWindow():frame()
    local focusedWindowCenter = focusedWindowFrame.center
    hs.mouse.absolutePosition(focusedWindowCenter)
end

module.allWindows = function()
    return hs.window.visibleWindows()
end

module.tile = function()

end

module.focusLeft = function()
    hs.window.focusedWindow().focusWindowWest(allWindows)
    centerMouseOnFocusedWindow()
end

module.focusRight = function()
    hs.window.focusedWindow().focusWindowEast(allWindows)
    centerMouseOnFocusedWindow()
end

module.focusUp = function()
    hs.window.focusedWindow().focusWindowNorth(allWindows)
    centerMouseOnFocusedWindow()
end

module.focusDown = function()
    hs.window.focusedWindow().focusWindowSouth(allWindows)
    centerMouseOnFocusedWindow()
end

return module
