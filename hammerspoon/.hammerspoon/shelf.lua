require 'util'

-- Returns the existing shelf with this ID
local function existingShelfPathWithID(id)
    -- Always make shelves directory
    hs.execute("mkdir -p ~/.shelves")

    -- Find with the name
    local matching = hs.execute("ls ~/.shelves/ |grep " .. id)
    matching = matching:gsub("\n", "")
    if string.len(matching) > 0 then
        -- plh-evil: split if multiple matches?
        return '~/.shelves/' .. matching
    else
        return nil
    end
end

function utiForShelfWithID(id)
    local path = existingShelfPathWithID(id)
    if path ~= nil then
        return hs.fs.fileUTI(path)
    else
        return '?'
    end
end

function shelfExistsWithID(id)
    return existingShelfPathWithID(id) ~= nil
end

-- Returns the icon for the shelf with this ID
function existingShelfIconWithID(id)
    local path = existingShelfPathWithID(id)
    if path == nil then return nil end
    return hs.image.iconForFile(path)
end

function writeTextToShelfWithID(id, text)
    -- Grab the path
    local path = existingShelfPathWithID(id)
    if path == nil then 
        path = '~/.shelves/' .. id .. '.txt'
    end

    -- Strike the ~, replace with the home dir
    path = path:sub(2)
    path = os.getenv("HOME") .. path
    path:gsub("~", "")

    dbg(path)

    local shelf = io.open(path, 'w')
    dbg(shelf)
    shelf:write(text)
    shelf:close()
end

-- Grabs the shelf data and writes it to id
function grabShelf(id)
    local text = hs.pasteboard.getContents()
    if text ~= nil then
        writeTextToShelfWithID(id, text)
    end
end

function clearShelfWithID(id)
    local path = existingShelfPathWithID(id)
    dbg("DELETE COMMAND FOR " .. path)
    os.execute('rm ' .. path)
end

