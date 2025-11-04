-- Link Replace Module
-- Automatically replaces certain URLs with farside.link privacy-respecting alternatives

local link_replace = {}

-- URLs that should be replaced with farside.link alternatives
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

-- Private helper function
local function startsWith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

-- Replace pasteboard link with farside.link if it matches one of the configured URLs
function link_replace.replacePasteboardLinkIfNecessary(contents)
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

return link_replace
