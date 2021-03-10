require "hyper"
require "terminal"

-- requires youtube-dl and my ytd script

local function youtubedl(url)
    local command = "ytd \""..url.."\""
    runInNewTerminal(command, true)
end

hs.hotkey.bind(hyper, "w", function()
    -- If Reeder is running, strip the URL
    local reeder = hs.application('com.reederapp.5.macOS')
    if reeder ~= nil then
        reeder:selectMenuItem("Copy Link")
    end
    -- Grab pasteboard
    local pasteboard = hs.pasteboard.readString()
    if string.find(pasteboard, 'http') then
        youtubedl(pasteboard)
    end
end)
