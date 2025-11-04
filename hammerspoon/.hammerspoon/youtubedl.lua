local hyper = require "hyper"
require "terminal"

-- requires youtube-dl and my ytd script

local function youtubedl(url)
    local command = "ytd \""..url.."\""
    runInNewTerminal(command, true)
end

hs.hotkey.bind(hyper.key, "w", function()
    -- Grab pasteboard
    local pasteboard = hs.pasteboard.readString()
    if string.find(pasteboard, 'http') then
        youtubedl(pasteboard)
    end
end)
