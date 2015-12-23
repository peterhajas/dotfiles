require "hyper"

-- Volume Control {{{

-- Number of volume "ticks"

function volumeTicks()
    return 10
end

-- Getting the current volume

function currentVolume()
    local volume = hs.audiodevice.current()['device']:volume()
    if volume ~= nil then
        return volume
    else
        -- No output controls available
        return 100
    end
end

-- Changing volume

function changeVolumeByAmount(amount)
    vol = currentVolume()
    delta = (100 / volumeTicks()) * amount
    newVol = currentVolume() + delta
    newVol = math.floor(newVol)

    local command = "set volume output volume " .. newVol .. " --100%"
    hs.applescript.applescript(command)
end

-- Hyper-- for volume down

hs.hotkey.bind(hyper, "-", function()
    changeVolumeByAmount(-1)
end)

-- Hyper-+ for volume up

hs.hotkey.bind(hyper, "=", function()
    changeVolumeByAmount(1)
end)

-- }}}
