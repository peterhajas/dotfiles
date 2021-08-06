-- Replaces links that are found on the clipboard, if applicable

local replacements = {
    ['twitter.com'] = 'nitter.net',
    ['/reddit.com'] = '/teddit.net',
    ['old.reddit.com'] = 'teddit.net',
    ['reddit.com'] = 'teddit.net',
    ['instagram.com'] = 'bibliogram.art'
}

function replacePasteboardLinkIfNecessary(contents)
    if contents == nil then
        return
    end

    for key, replacement in pairs(replacements) do
        if string.find(contents, key) then
            newContents = contents:gsub(key, replacement)
            hs.pasteboard.setContents(newContents)
            hs.alert("Replaced")
        end
    end
end
