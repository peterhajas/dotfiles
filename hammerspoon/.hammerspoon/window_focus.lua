-- Window Focus Module
-- Focus the nearest window east/west of the current focus, wrapping around
-- the leftmost/rightmost visible window if there's nothing further in that
-- direction. Uses hs.window's built-in directional focus, which crosses
-- displays.

local window_focus = {}

local function wrapTo(direction, current)
    local candidates = {}
    for _, w in ipairs(hs.window.visibleWindows()) do
        if current == nil or w:id() ~= current:id() then
            table.insert(candidates, w)
        end
    end
    if #candidates == 0 then return false end
    table.sort(candidates, function(a, b)
        return a:frame().x < b:frame().x
    end)
    local target = direction == "east" and candidates[1] or candidates[#candidates]
    target:focus()
    return true
end

local function focusDirection(direction)
    local current = hs.window.focusedWindow()
    if current == nil then
        return wrapTo(direction, nil)
    end
    local method = direction == "east" and "focusWindowEast" or "focusWindowWest"
    -- nil candidates = all visible; true = prefer unoccluded
    if current[method](current, nil, true) then
        return true
    end
    return wrapTo(direction, current)
end

function window_focus.east()
    return focusDirection("east")
end

function window_focus.west()
    return focusDirection("west")
end

return window_focus
