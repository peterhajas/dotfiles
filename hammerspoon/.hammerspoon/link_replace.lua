-- Replaces links that are found on the clipboard, if applicable

function replacePasteboardLinkIfNecessary(contents)
    if contents == nil then
        return
    end
    if string.find(contents, 'twitter.com') then
        -- Replace twitter.com with nitter.net
        newContents = contents:gsub('twitter.com', 'nitter.net')
        hs.pasteboard.setContents(newContents)
        hs.alert("Nitter Replaced")
    end
end
