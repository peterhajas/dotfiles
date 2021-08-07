require "shelf"

function shelfButtonForShelfWithID(id)
    return {
        ['name'] = 'Shelf ' .. id,
        ['imageProvider'] = function()
            local existing = existingShelfIconWithID(id)
            if existing ~= nil then
                return existing
            end

            return streamdeck_imageFromText(id)
        end,
        ['onClick'] = function()
            -- If we have a shelf item, then perform the action with it
            if shelfExistsWithID(id) then
                dbg("act")
                actOnShelf(id)
            -- Otherwise, put stuff on the shelf
            else
                dbg("grab")
                grabShelf(id)
            end
        end,
        ['onLongPress'] = function()
            -- If we have a shelf item, delete
            -- Otherwise, nothing
            if shelfExistsWithID(id) then
                clearShelfWithID(id)
            end
        end,
        ['updateInterval'] = 1,
        ['stateProvider'] = function()
            return utiForShelfWithID(id)
        end
    }
end

