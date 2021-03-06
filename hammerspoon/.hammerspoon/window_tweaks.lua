require "colors"

local windowBorder = nil

function operateOnWindow(window, appName, eventName)
    if windowBorder == nil then
        windowBorder = hs.drawing.rectangle(hs.geometry.rect(0,0,0,0))
        windowBorder:setStrokeColor(tintColor)
        windowBorder:setRoundedRectRadii(5.0, 5.0)
        windowBorder:setFill(false)
        windowBorder:setStrokeWidth(4)
    end

    local frontMostWindow = hs.window.focusedWindow()

    if frontMostWindow ~= nil then
        windowBorder:show()
        windowBorder:setFrame(frontMostWindow:frame())
    else
        windowBorder:hide()
    end
end

allWindows = hs.window.filter.new(nil)

interestingWindowEvents = { hs.window.filter.windowDestroyed,
                            hs.window.filter.windowFocused,
                            hs.window.filter.windowUnfocused,
                            hs.window.filter.windowMoved }

allWindows:subscribe(interestingWindowEvents, operateOnWindow)
