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

function clearShelfWithID(id)
    local path = existingShelfPathWithID(id)
    if path ~= nil then
        dbg("DELETE COMMAND FOR " .. path)
        os.execute('rm ' .. path)
    end
end

function allShelfIDs()
    local ids = hs.execute("ls ~/.shelves")
    ids = split(ids, '\n')
    return ids
end

local function extension(url)
    local components = split(url, '.')
    return components[#components]
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

function outputPathForShelfWithIDAndExtension(id, extension)
    -- Grab the path
    local path = existingShelfPathWithID(id)
    if path == nil then 
        path = '~/.shelves/' .. id .. '.' .. extension
    end

    -- Strike the ~, replace with the home dir
    path = path:sub(2)
    path = os.getenv("HOME") .. path
    path:gsub("~", "")

    return path
end

function writeTextToShelfWithID(id, text)
    local path = outputPathForShelfWithIDAndExtension(id, 'txt')
    local shelf = io.open(path, 'w')
    shelf:write(text)
    shelf:close()
end

function writeFileURLToShelfWithID(id, url)
    clearShelfWithID(id)
    local path = outputPathForShelfWithIDAndExtension(id, extension(url))

    os.execute('cp ' .. url .. ' ' .. path)
end

function writeRemoteURLToShelfWithID(id, url)
    clearShelfWithID(id)
    local path = outputPathForShelfWithIDAndExtension(id, extension(url))

    os.execute('curl ' .. url .. ' >' .. path)
end

-- Grabs the shelf data and writes it to id
function grabShelf(id)
    local url = hs.pasteboard.readURL()
    local text = hs.pasteboard.readString()
    if url ~= nil then
        dbg("URL")
        dbg(url)
        local fileURL = url['filePath']
        local remoteURL = url['url']
        if fileURL ~= nil then
            writeFileURLToShelfWithID(id, filePath)
        else
            writeRemoteURLToShelfWithID(id, remoteURL)
        end
    elseif text ~= nil then
        dbg("TEXT")
        dbg(text)
        writeTextToShelfWithID(id, text)
    end
end

-- Acts on the shelf data for id
function actOnShelf(id)
    local path = existingShelfPathWithID(id)
    path = outputPathForShelfWithIDAndExtension(id, extension(path))
    if path ~= nil then
        local out = hs.execute('open ' .. path)
        dbg(out)
    end
end


