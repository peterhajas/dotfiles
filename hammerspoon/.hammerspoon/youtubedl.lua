require "hyper"
require "terminal"

-- requires youtube-dl and my ytd script

hs.hotkey.bind(hyper, "w", function()
    -- Grab pasteboard
    local pasteboard = hs.pasteboard.readString()
    if string.find(pasteboard, 'http') then
        local command = "ytd \""..pasteboard.."\""
        runInNewTerminal(command, true)
    end
end)
