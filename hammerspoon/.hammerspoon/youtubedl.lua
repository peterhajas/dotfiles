-- YouTube Download Module
-- Downloads videos from URLs in pasteboard via Hyper-W

local youtubedl = {}

local hyper = require "hyper"
require "terminal"

-- Private helper function
local function downloadVideo(url)
    local command = "ytd \""..url.."\""
    runInNewTerminal(command, true)
end

-- Initialize YouTube downloader
function youtubedl.init()
    -- Hyper-W to download video from pasteboard URL
    hs.hotkey.bind(hyper.key, "w", function()
        -- Grab pasteboard
        local pasteboard = hs.pasteboard.readString()
        if string.find(pasteboard, 'http') then
            downloadVideo(pasteboard)
        end
    end)
end

return youtubedl
