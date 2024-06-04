-- Replaces links that are found on the clipboard, if applicable

local urlsToReplace = {
    'imgur.com',
    'instagram.com',
    'medium.com',
    'mobile.twitter.com',
    'old.reddit.com',
    'reddit.com',
    'tiktok.com',
    'twitter.com',
    'x.com',
}

local function startsWith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

function replacePasteboardLinkIfNecessary(contents)
    if contents == nil then
        return
    end

    for _, rep in ipairs(urlsToReplace) do
        local https = "https://" .. rep
        local www = "https://www." .. rep
        if startsWith(contents, https) or startsWith(contents, www) then
            local newContents = "https://farside.link/" .. contents
            hs.pasteboard.setContents(newContents)
            hs.alert("Replaced")
            return
        end
    end
end
