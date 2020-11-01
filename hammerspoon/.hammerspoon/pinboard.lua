require "hyper"

function addToPinboard(url)
    -- Make a request to find the title
    hs.http.doAsyncRequest(url, "GET", nil, nil, function(response, body, headers)
        -- Search the body for the title tag
        local tagStart = string.find(body, '<title>')
        local tagEnd = string.find(body, '</title>')
        if tagStart == nil or tagEnd == nil then
            hs.alert("Couldn't find title - bailing")
        end
        -- Offset tag start by length of '<title>'
        tagStart = tagStart + 7
        tagEnd = tagEnd - 1
        title = string.sub(body, tagStart, tagEnd)

        -- Ask for tags
        button, result = hs.dialog.textPrompt("Add to Pinboard", "Space-delimited tags for \""..title.."\"", "", "Add", "Cancel")
        -- Make sure something was entered
        if string.len(result) == 0 then
            return
        end

        -- Call the pinboard script
        local urlPart = '--url \''..url..'\''
        local titlePart = ' --title \''..title..'\''
        local tagsPart = ' --tags \''..result..'\''
        local readPart = ' --read'

        local command = 'pinboard add '..urlPart..titlePart..tagsPart..readPart
        local output = hs.execute(command, true)
    end, "protocolCachePolicy")
end

hs.hotkey.bind(hyper, "d", function()
    local str = hs.pasteboard.readString()
    -- Verify there's a string in there
    if str == nil then
        return
    end

    -- Make sure it's a URL
    if not string.find(str, "http") then
        return
    end
    addToPinboard(str)
end)
