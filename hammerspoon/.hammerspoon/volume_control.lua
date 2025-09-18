require "hyper"
require "util"
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
    local displayName = hs.screen.primaryScreen():name()
    local outputName = hs.audiodevice.current(false)['name']

    local connectedToSamsung = displayName == "SAMSUNG" or displayName == "Odyssey Ark"
    local audioOutputIsSamsung = outputName == 'SAMSUNG' or outputName == "Odyssey Ark"
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

