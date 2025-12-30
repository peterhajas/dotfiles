-- Audio Output Module
-- Watches for audio device changes and updates Stream Deck

local audio_output = {}

local streamdeck = require('streamdeck')

-- Private state
local lastSeenName = ""

-- Initialize audio output watcher
function audio_output.init()
    hs.audiodevice.watcher.setCallback(function(kind)
        streamdeck:updateButton('audio')
    end)

    hs.audiodevice.watcher.start()
end

return audio_output

