require 'streamdeck'

local lastSeenName = ""

hs.audiodevice.watcher.setCallback(function(kind)
    streamdeck_updateButton('audio')
end)

hs.audiodevice.watcher.start()

