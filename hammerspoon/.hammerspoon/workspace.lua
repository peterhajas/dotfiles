
-- Key: window ID
-- Value: table:
--   Keys: 'space', 'shownFrame'
windowMap = { }

-- Key: space number (1-indexed)
-- Value: table:
--   Keys: 'focusedWindowID'
spaceMap = { }

-- The current space, 1-indexed
currentSpace = 1

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
    if windowMap[windowID] == nil then return end
    if windowMap[windowID]['shownFrame'] ~= nil then return end

    local window = hs.window(windowID)
    if window == nil then return end
    windowMap[windowID]['shownFrame'] = window:frame()

    local newFrame = window:frame()
    newFrame.x = 10000
    newFrame.y = 10000
    window:setFrame(newFrame)
end

local function bringWindowBack(windowID)
    if windowMap[windowID] == nil then return end
    local window = hs.window(windowID)
    if window == nil then return end
    if windowMap[windowID]['shownFrame'] == nil then return end

    window:setFrame(windowMap[windowID]['shownFrame'])
    windowMap[windowID]['shownFrame'] = nil
end

local function update()
    local someWindowInCurrentSpace = nil
    for windowID, windowInfo in pairs(windowMap) do
        local space = windowInfo['space']
        if space ~= currentSpace then
            sendWindowAway(windowID)
        else
            bringWindowBack(windowID)
            someWindowInCurrentSpace = window
        end
    end

    local spaceInfo = spaceMap[currentSpace] or { }
    local windowIDToFocus = spaceInfo['focusedWindowID']
    if windowIDToFocus ~= nil then
        local windowToFocus = hs.window(windowID)
        if windowToFocus ~= nil then
            windowToFocus:focus()
        end
    end
end

local function switchToSpace(space)
    if space ~= currentSpace then
        currentSpace = space
        update()
    end
end

local function moveWindowToSpace(window, space)
    windowMap[window:id()]['space'] = space
    update()
end

local function windowCreated(window)
    windowMap[window:id()] = { }
    windowMap[window:id()]['space'] = currentSpace
end

local function windowDestroyed(window)
    windowMap[window:id()] = nil
end

local function windowFocused(window)
    -- plh-evil: this needs some fixes, so it is disabled below
    -- what needs to change::
    -- - if a window is moving spaces, we need to remove it from our focused
    --   window tracking, and find the next window to focus for our space

    -- Switch to that space, or mark this window as focused for this space
    local windowSpace = spaceForWindowID(window:id())
    if windowSpace == nil then return end

    if windowSpace ~= currentSpace then
        switchToSpace(windowSpace)
    else
        spaceMap[currentSpace] = { }
        spaceMap[currentSpace]['focusedWindowID'] = window:id()
    end
end

for k,i in pairs({1,2,3,4,5}) do
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
        -- windowFocused(window)
    end
end, true)

