
-- Key: window ID
-- Value: space that window is in
trackedWindowIDs = { }

-- Key: window ID
-- Value: frame when this window is regularly presented
normalWindowFrames = { }

-- The current space, 1-indexed
currentSpace = 1

-- The window last focused in each space
-- Key: space ID
-- Value: window ID
spacesToFocusedWindows = { }

-- Whether or not we're in setup mode
inSetup = true

local function sendWindowAway(windowID)
    local window = hs.window(windowID)
    if window == nil then return end

    dbg("HIDING " .. tostring(windowID))

    -- if normalWindowFrames[windowID] == nil then
    --     normalWindowFrames[windowID] = window:frame()
    --     local newFrame = window:frame()
    --     newFrame.x = 10000
    --     newFrame.y = 10000
    --     window:setFrame(newFrame)
    -- end
end

local function bringWindowBack(windowID)
    local window = hs.window(windowID)
    if window == nil then return end

    dbg("SHOWING " .. tostring(windowID))

    -- local newFrame = normalWindowFrames[windowID]
    -- if newFrame ~= nil then
    --     window:setFrame(newFrame)
    -- end
    -- normalWindowFrames[windowID] = nil
end

local function update()
    if inSetup then return end
    local someWindowInCurrentSpace = nil
    for windowID, space in pairs(trackedWindowIDs) do
        if space ~= currentSpace then
            sendWindowAway(windowID)
        else
            bringWindowBack(windowID)
            someWindowInCurrentSpace = window
        end
    end

    -- if trackedWindowIDs[hs.window.frontmostWindow:id()] ~= currentSpace then
    --     local windowToFocus = hs.window(spacesToFocusedWindows[currentSpace]) or someWindowInCurrentSpace
    --     if windowToFocus ~= nil then
    --         windowToFocus:focus()
    --     end
    -- end
end

local function switchToSpace(space)
    dbg("Switch to " .. tostring(space))
    if space ~= currentSpace then
        currentSpace = space
        update()
    end
end

local function moveWindowToSpace(window, space)
    trackedWindowIDs[window:id()] = space
    update()
end

local function windowCreated(window)
    moveWindowToSpace(window, currentSpace)
end

local function windowDestroyed(window)
    trackedWindowIDs[window:id()] = nil
end

local function windowFocused(window)
    -- Switch to that space, or earmark this window
    local newSpace = trackedWindowIDs[window:id()] or currentSpace
    if newSpace ~= currentSpace then
        switchToSpace(newSpace)
    else
        spacesToFocusedWindows[newSpace] = window:id()
    end
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

for k,i in pairs({1,2,3,4,5}) do
    hs.hotkey.bind({"alt"}, tostring(i), function()
        switchToSpace(i)
    end)
    hs.hotkey.bind({"alt", "shift"}, tostring(i), function()
        moveWindowToSpace(hs.window.frontmostWindow(), i)
    end)
end

inSetup = false

