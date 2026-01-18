-- Link Replace Module
-- Automatically replaces certain URLs with farside.link privacy-respecting alternatives

local link_replace = {}

local scriptPath = os.getenv("HOME") .. "/bin/link_transform"
local pasteboardWatcher = nil

local function shellEscape(value)
    if value == nil then
        return "''"
    end

    return "'" .. value:gsub("'", "'\\''") .. "'"
end

-- Replace pasteboard link with farside.link if it matches one of the configured URLs
function link_replace.replacePasteboardLinkIfNecessary(contents)
    if contents == nil then
        return
    end

    local command = "printf %s " .. shellEscape(contents) .. " | " .. scriptPath
    local output = hs.execute(command, true)
    if output ~= nil and output ~= "" and output ~= contents then
        hs.pasteboard.setContents(output)
        hs.alert("Replaced")
    end
end

function link_replace.init()
    if pasteboardWatcher ~= nil then
        return
    end

    pasteboardWatcher = hs.pasteboard.watcher.new(function(contents)
        link_replace.replacePasteboardLinkIfNecessary(contents)
    end)
    pasteboardWatcher:start()
end

return link_replace
