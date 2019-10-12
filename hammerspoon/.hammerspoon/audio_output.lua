-- Audio Output {{{

local lastSeenName = ""

hs.audiodevice.watcher.setCallback(function(kind)
    if kind == "dOut" or kind == "sOut" then
        local name = hs.audiodevice.current()['name']
        if name ~= lastSeenName then
            lastSeenName = name
            local volume = hs.audiodevice.current()['volume']
            if volume == nil then
                volume = ""
            end
            local alertText = "🔉 " .. name .. " " .. volume
            hs.alert(alertText, hs.screen.primaryScreen())
        end
    end
end)

hs.audiodevice.watcher.start()

-- }}}
