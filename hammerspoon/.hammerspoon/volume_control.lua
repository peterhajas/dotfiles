require "hyper"
require "home_assistant"

-- Volume Control {{{

-- Number of volume "ticks"

function volumeTicks()
    return 20
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

local function shouldChangeTVVolume()
    local connectedToSamsung = hs.screen.primaryScreen():name() == 'SAMSUNG'
    local audioOutputIsSamsung = hs.audiodevice.current(false)['name'] == 'SAMSUNG'
    return connectedToSamsung and audioOutputIsSamsung
end

function changeVolumeByAmount(amount)
    if shouldChangeTVVolume() then
        local webhookName = 'office_samsung_volume_up'
        if amount < 0 then
            webhookName = 'office_samsung_volume_down'
        end

        local url = 'http://beacon:8123' .. '/api/webhook/' .. webhookName
        hs.http.post(url, nil, nil)

        return
    end
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
