
local function homeRoot()
    local home = hs.application'Home'
    -- 1 is window, 2 is menu bar
    return hs.axuielement.applicationElement(home).AXChildren[1]
end

local function performWithRoomsParent(home, perform)
    search = homeRoot():elementSearch(function(m, r, c)
        local parent = r[1]
        if parent ~= nil then
            parent = parent.AXParent
            perform(parent)
        end
    end, function(e)
        return e.AXDescription == "Automation"
    end)
end

local function performWithRoomSidebarElements(home, perform)
    performWithRoomsParent(home, function(roomsParent)
        local rooms = { }
        for i, v in pairs(roomsParent.AXChildren) do
            -- Filter out non-room sections
            if (v.AXDescription ~= "Home" and
                v.AXDescription ~= "Automation" and
                v.AXDescription ~= "Rooms") then
                rooms[#rooms+1] = v
            end
        end

        perform(rooms)
    end)
end

local function performWithCurrentContentParent(home, perform)
    search = homeRoot():elementSearch(function(m, r, c)
        local parent = r[1]
        if parent ~= nil then
            parent = parent.AXParent
            perform(parent)
        end
    end, function(e)
        return e.AXDescription == "Accessories" and
               e.AXRole == "AXHeading"
    end)
end

local function performWithCurrentAccessoryElements(home, perform)
    performWithCurrentContentParent(home, function(contentParent)
        local accessories = { }
        for i, v in pairs(contentParent.AXChildren) do
            if (v.AXDescription ~= nil and
                v.AXRole == "AXButton") then
                accessories[#accessories+1] = v
            end
        end

        perform(accessories)
    end)
end

-- Grabs rooms
--- context: any context for the request (unused currently), may be `nil`
--- perform: a function which will be called with the rooms in your home
---- `perform` will be called with a table of tables representing the rooms.
---- Each room table has the following keys:
----- "name" - the name of the room
---- all other keys are internal-only
function rooms(context, perform)
    local home = nil
    performWithRoomSidebarElements(home, function(elements)
        local rooms = { }
        for i, v in pairs(elements) do
            local tableForRoom = { }
            tableForRoom['name'] = v.AXDescription
            tableForRoom['_element'] = v
            rooms[#rooms+1] = tableForRoom
        end

        perform(rooms)
    end)
end

-- Grabs accessories
--- context: any context for the request (unused currently), may be `nil`
--- room: the room for the request. This should be a room object returned from
---       the above `rooms()` function.
--- perform: a function which will be called with the accessories in the room
---- `perform` will be called with a table of tables representing the
---- accessories. 
---- Each accessory table has the following keys:
----- "name" - the name of the accessory
----- "toggle" - a function which will toggle the accessory
---- all other keys are internal-only

function accessories(context, room, perform)
    -- First, switch to the room
    room['_element']:performAction('AXPress')

    -- Next, get accessories
    local home = nil
    performWithCurrentAccessoryElements(nil, function(elements)
        local accessories = { }
        for i, v in pairs(elements) do
            local tableForAccessory = { }
            tableForAccessory['name'] = v.AXDescription
            tableForAccessory['_element'] = v
            tableForAccessory['toggle'] = function()
                tableForAccessory['_element']:performAction('AXPress')
            end
            accessories[#accessories+1] = tableForAccessory
        end

        perform(accessories)
    end)
end

function doRoomsTest()
    rooms(nil, function(rooms)
        hs.alert(hs.inspect(rooms))
    end)
end

function doAccessoriesTest()
    rooms(nil, function(rooms)
        local theOffice = rooms[5]
        accessories(nil, theOffice, function(accessories)
            local theLight = accessories[1]
            theLight['toggle']()
        end)
    end)
end

