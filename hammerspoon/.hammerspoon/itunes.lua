require 'hyper'
require 'status'

-- Status Frames

function iTunesStatusFrame()
    local width = 400
    local frame = statusFrameForXAndWidth(statusEdgePadding(), width)
    return frame
end

-- Brightness Control

function changeBrightnessInDirection (d)
    local brightnessChangeAmount = 16
    local brightness = hs.brightness.get()

    brightness = brightness + (brightnessChangeAmount * d)

    hs.brightness.set(brightness)
end


-- iTunes Current Track Display

local iTunesStatusText
local iTunesStatusTextBackground

function destroyiTunesTrackDisplay()
    if iTunesStatusText then iTunesStatusText:delete() end
    if iTunesStatusTextBackground then iTunesStatusTextBackground:delete() end
end

function updateiTunesTrackDisplay()
    local statusText = ''
    if hs.appfinder.appFromName('iTunes') and 
        type(hs.itunes.getCurrentTrack()) == 'string' then
        local trackName = hs.itunes.getCurrentTrack()
        local artistName = hs.itunes.getCurrentArtist()
        statusText = trackName .. ' by ' .. artistName
    end

    iTunesStatusText:setText(statusText)
end

function buildiTunesTrackDisplay()
    destroyiTunesTrackDisplay()
    local frame = iTunesStatusFrame()
    iTunesStatusText = hs.drawing.text(frame, '')
    iTunesStatusTextBackground = hs.drawing.rectangle(frame)

    iTunesStatusText:setTextColor(statusTextColor()):setTextSize(statusTextColor):sendToBack():show()
    updateiTunesTrackDisplay()
end

buildiTunesTrackDisplay()

-- Media Player Controls

-- Hyper-8 plays/pauses music

hs.hotkey.bind(hyper, "8", function()
    hs.itunes.play()
    updateiTunesTrackDisplay()
end)

-- Hyper-0 goes to the next track

hs.hotkey.bind(hyper, "0", function()
    hs.itunes.next()
    updateiTunesTrackDisplay()
end)

-- Hyper-9 goes to the previous track

hs.hotkey.bind(hyper, "9", function()
    hs.itunes.previous()
    updateiTunesTrackDisplay()
end)

