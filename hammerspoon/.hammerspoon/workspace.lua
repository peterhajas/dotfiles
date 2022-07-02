
-- Key: window ID
-- Value: table:
--   Keys: 'space', 'shownUnitTopLeft', 'lastFocusTime'
windowMap = { }

-- Key: space number (1-indexed)
-- Value: table:
spaceMap = { }

-- The current space, 1-indexed
currentSpace = 1

-- Our menu item
workspaceMenuItem = hs.menubar.new()

function spacesDebug()
    print('Current space: ' .. currentSpace)
    print('windowMap:')
    dbg(windowMap)

    print('spaceMap:')
    dbg(spaceMap)
end

local function spaceForWindowID(windowID)
    local windowInfo = windowMap[windowID] or { ['space'] = currentSpace }
    return windowInfo['space']
end

local function sendWindowAway(windowID)
    -- if windowMap[windowID] == nil then return end
    -- if windowMap[windowID]['shownUnitTopLeft'] ~= nil then return end

    -- local window = hs.window(windowID)
    -- if window == nil then return end

    -- local screen = window:screen()
    -- local unitPoint = window:topLeft()
    -- local scaleFactor = screen:frame()

    -- unitPoint.x = unitPoint.x / scaleFactor.w
    -- unitPoint.y = unitPoint.y / scaleFactor.h

    -- windowMap[windowID]['shownUnitTopLeft'] = unitPoint

    -- window:setTopLeft(hs.geometry.point(10000,10000))
end

local function bringWindowBack(windowID)
    if windowMap[windowID] == nil then return end
    -- if windowMap[windowID]['shownUnitTopLeft'] == nil then return end

    local window = hs.window(windowID)
    if window == nil then return end

    window:focus()

    -- local screen = window:screen()
    -- local windowTopLeft = windowMap[windowID]['shownUnitTopLeft']
    -- local scaleFactor = screen:frame()

    -- windowTopLeft.x = windowTopLeft.x * scaleFactor.w
    -- windowTopLeft.y = windowTopLeft.y * scaleFactor.h

    -- window:setTopLeft(windowTopLeft)
    -- windowMap[windowID]['shownUnitTopLeft'] = nil
end

local function update()
    local populatedSpaces = { }

    local windowIDToFocusInSpace = nil
    local windowIDToFocusInSpaceLastFocusTime = 0
    
    -- Update windows
    for windowID, windowInfo in pairs(windowMap) do
        local space = windowInfo['space']
        populatedSpaces[space] = true
        if space ~= currentSpace then
            sendWindowAway(windowID)
        else
            bringWindowBack(windowID)
            local lastFocusTime = windowInfo['lastFocusTime'] or -1
            if windowIDToFocusInSpaceLastFocusTime < lastFocusTime then
                windowIDToFocusInSpace = windowID
                windowIDToFocusInSpaceLastFocusTime = lastFocusTime
            end
        end
    end

    -- Update menu item
    local menuItemText = hs.styledtext.new('')
    for spaceNumber, spaceInfo in pairs(spaceMap) do
        local textForSpaceNumber = ' ' .. tostring(spaceNumber) .. ' '
        if spaceNumber == currentSpace then
            -- If we're in this space, then add it
            menuItemText = menuItemText .. hs.styledtext.new(textForSpaceNumber, { ['color'] = tintColor })
        else
            -- Only add if there are windows in this space
            if populatedSpaces[spaceNumber] ~= nil then
                menuItemText = menuItemText .. hs.styledtext.new(textForSpaceNumber)
            end
        end
    end
    workspaceMenuItem:setTitle(menuItemText)

    -- Update focus
    if windowIDToFocusInSpace ~= nil then
        local windowToFocus = hs.window(windowIDToFocusInSpace)
        if windowToFocus ~= nil then
            windowToFocus:focus()
        end
    end
end

local function switchToSpace(space)
    if space ~= currentSpace then
        currentSpace = space
        update()
    else
        hs.sound.getByName("Tink"):play()
    end
end

-- Faults in any storage we might need
local function windowManipulated(window)
    if windowMap[window:id()] == nil then
        windowMap[window:id()] = { }
    end
end

local function moveWindowToSpace(window, space)
    windowManipulated(window)
    windowMap[window:id()]['space'] = space
    update()
end

local function windowCreated(window)
    windowManipulated(window)
    windowMap[window:id()]['space'] = currentSpace
end

local function windowDestroyed(window)
    windowMap[window:id()] = nil
end

local function windowFocused(window)
    windowManipulated(window)
    -- Update our last-focused time
    windowMap[window:id()]['lastFocusTime'] = hs.timer.secondsSinceEpoch()
end

-- Resets the workspaces so windows all come back
function workspaceReset()
    local newSpace = 1
    switchToSpace(newSpace)
    for windowID, windowInfo in pairs(windowMap) do
        windowMap[windowID]['space'] = newSpace
    end
    update()
end

for k,i in pairs({1,2,3,4,5,6,7,8,9,0}) do
    spaceMap[i] = { }

    hs.hotkey.bind({"alt"}, tostring(i), function()
        switchToSpace(i)
    end)
    hs.hotkey.bind({"alt", "shift"}, tostring(i), function()
        moveWindowToSpace(hs.window.frontmostWindow(), i)
    end)
end

workspaceWindowFilter = hs.window.filter.copy(hs.window.filter.default)
:rejectApp('Hammerspoon')
:subscribe({hs.window.filter.windowCreated, hs.window.filter.windowDestroyed, hs.window.filter.windowFocused}, function(window, appName, event)
    if event == hs.window.filter.windowCreated then
        windowCreated(window)
    elseif event == hs.window.filter.windowDestroyed then
        windowDestroyed(window)
    elseif event == hs.window.filter.windowFocused then
        windowFocused(window)
    end
end, true)

update()

