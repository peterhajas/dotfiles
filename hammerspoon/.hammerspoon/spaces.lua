require "util"

-- Currently unused and not included in `init.lua`.

dbg("HEY")

function goLeft()
    local command 
    hs.execute("open \"btt://trigger_named/?trigger_name=" .. "LEFT" .. "\"")
end

function goRight()
    hs.execute("open \"btt://trigger_named/?trigger_name=" .. "RIGHT" .. "\"")
end

function goToSpace(index)
    local focusedWindow = hs.window.focusedWindow()
    local focusedScreen = focusedWindow:screen()
    local spacesOnScreen = hs.spaces.spacesForScreen(focusedScreen)
    local currentSpaceNumber = hs.spaces.activeSpaceOnScreen(focusedScreen)

    local currentIndex = findIndex(spacesOnScreen, currentSpaceNumber)
    if currentIndex == nil then
        return
    end

    local difference = index - currentIndex
    if difference == 0 then
        return
    end

    for i = 1, math.abs(difference) do
        if difference < 0 then
            goLeft()
        else
            goRight()
        end
    end
end

hs.hotkey.bind({"alt"}, "1", function() goToSpace(1) end)
hs.hotkey.bind({"alt"}, "2", function() goToSpace(2) end)
hs.hotkey.bind({"alt"}, "3", function() goToSpace(3) end)
hs.hotkey.bind({"alt"}, "4", function() goToSpace(4) end)
hs.hotkey.bind({"alt"}, "5", function() goToSpace(5) end)
hs.hotkey.bind({"alt"}, "6", function() goToSpace(6) end)
hs.hotkey.bind({"alt"}, "7", function() goToSpace(7) end)
hs.hotkey.bind({"alt"}, "8", function() goToSpace(8) end)
hs.hotkey.bind({"alt"}, "9", function() goToSpace(9) end)
hs.hotkey.bind({"alt"}, "0", function() goToSpace(10) end)

