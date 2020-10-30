require "streamdeck_buttons.button_images"

local function allAudioDevices(input)
    local devices
    if input then
        devices = hs.audiodevice.allInputDevices()
    else
        devices = hs.audiodevice.allOutputDevices()
    end
    return devices
end

local function indexAndCountOfAudioDevices(input)
    local allDevices = allAudioDevices(input)
    local deviceName = hs.audiodevice.current(input)['name']
    local index = -1
    local count = 0

    for k,v in pairs(allDevices) do
        if v:name() == deviceName then
            index = k
        end
        count = count + 1
    end

    return {
        ['index'] = index,
        ['count'] = count
    }
end

-- Returns a button for controlling audio devices
-- `input` controls whether this is an input device
--         or an output device button
function audioDeviceButton(input)
    local name = "audio_"
    if input then
        name = name .. 'input'
    else
        name = name .. 'output'
    end
    return {
        ['imageProvider'] = function (pressed)
            local deviceName = hs.audiodevice.current(input)['name']
            local indexAndCount = indexAndCountOfAudioDevices(input)
            local empty = "􀀀"
            local full = ""
            if input then
                full = "􀊱"
            else
                full = "􀊩"
            end
            local pageIndicator = ""
            local fillProgress = 1

            -- Add in empty circles until we hit the selected index
            while fillProgress < indexAndCount['index'] do
                pageIndicator = pageIndicator .. empty
                fillProgress = fillProgress + 1
            end

            -- Add in full circle
            pageIndicator = pageIndicator .. full
            fillProgress = fillProgress + 1

            -- Add in empty circles until we hit the count
            while fillProgress <= indexAndCount['count'] do
                pageIndicator = pageIndicator .. empty
                fillProgress = fillProgress + 1
            end

            local text = '\n' .. pageIndicator .. '\n' .. deviceName
            return streamdeck_imageFromText(text, { ['fontSize'] = 15 })
        end,
        ['pressUp'] = function()
            local allDevices = allAudioDevices(input)
            local indexAndCount = indexAndCountOfAudioDevices(input)
            local index = indexAndCount['index']
            local count = indexAndCount['count']

            if index ~= -1 then
                index = index + 1
            end
            if index > count then
                index = 1
            end

            if input then
                allDevices[index]:setDefaultInputDevice()
            else
                allDevices[index]:setDefaultOutputDevice()
            end
        end,
        ['name'] = name,
    }
end
