local storage = {
    -- "Containers" are like they are in the i3 sense. Just an array of nodes
    -- goes in each one, and then we lay out relative to the nodes we have
    -- For example:
    --
    -- Container1
    --   Safari
    --   Mail
    -- Container2
    --   Messages
    --   Reeder
    --   Container3
    --     HomeAssistant
    --     TextEdit
    --
    -- These are stored as tables. The table is basically a union - it can have
    -- a key of "windowID" for the window it refers to, or a key of "children"
    -- for the items it contains.
    ['containers'] = { }
}
local module = { storage = storage }

local function centerMouseOnFocusedWindow()
    local focusedWindowFrame = hs.window.focusedWindow():frame()
    local focusedWindowCenter = focusedWindowFrame.center
    hs.mouse.absolutePosition(focusedWindowCenter)
end

module.allWindows = function()
    return hs.window.visibleWindows()
end

-- items - table (see "containers" above)
-- rect - availabe rect for layout
-- direction - "x" or "y"
local function tile(items, rect, direction)
    local itemsToLayout = items

    local availableSize = hs.geometry.size(rect.w, rect.h)
    local itemSize = availableSize
    if direction == 'x' then
        itemSize.w = availableSize.w / #itemsToLayout
    else
        itemSize.h = availableSize.h / #itemsToLayout
    end

    local index = 0
    hs.fnutils.ieach(itemsToLayout, function(item)
        local itemRect = hs.geometry.rect(0,0,itemSize.w,itemSize.h)
        if direction == 'x' then
            itemRect.x = rect.x + (index * itemSize.w)
        else
            itemRect.y = rect.y + (index * itemSize.h)
        end
        local windowID = item['windowID']
        local children = item['children']
        if windowID ~= nil then
            local window = hs.window.find(item.windowID)
            window:setFrame(itemRect)
        end
        if children ~= nil then
            local childDirection = 'x'
            if direction == 'x' then
                childDirection = 'y'
            end
            tile(children, itemRect, childDirection)
        end

        index = index + 1
    end)
end

module.tile = function()
    storage['containers'] = { }
    -- plh-evil: multiple screens?
    hs.fnutils.ieach(module.allWindows(), function(win)
        local windowIDEntry = {
            ['windowID'] = win:id()
        }
        table.insert(storage['containers'],(windowIDEntry))
    end)
    tile(storage['containers'], hs.screen.mainScreen():frame(), 'x')
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

hs.window.filter.default:subscribe({ hs.window.filter.windowsChanged }, module.tile)

return module
