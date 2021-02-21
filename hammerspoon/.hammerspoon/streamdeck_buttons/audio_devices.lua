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

local imageCanvas = hs.canvas.new { w = buttonWidth, h = buttonHeight }

-- Returns a button for controlling audio devices
-- `input` controls whether this is an input device
--         or an output device button
function audioDeviceButton(input)
    -- This draws a button with a list of devices in it
    local name = "audio_"
    if input then
        name = name .. 'input'
    else
        name = name .. 'output'
    end
    return {
        ['imageProvider'] = function (pressed)
            local currentDeviceName = hs.audiodevice.current(input)['name']

            local elements = { }

            local yOffset = 0
            local fontSize = 14
            local yOffsetAmount = 13

            for k,v in pairs(allAudioDevices(input)) do
                local text = empty
                local color = hs.drawing.color.white
                if v:name() == currentDeviceName then
                    text = full
                    color = hs.drawing.color.lists()['Apple']['Orange']
                end

                deviceItem = {
                    frame = { x = 10, y = yOffset, w = 100000, h = buttonHeight },
                    text = hs.styledtext.new(v:name(), {
                        font = { name = ".AppleSystemUIFont", size = fontSize },
                        paragraphStyle = { alignment = "left" },
                        color = color
                    }),
                    type = "text",
                }
                table.insert(elements, indicatorItem)
                table.insert(elements, deviceItem)

                yOffset = yOffset + yOffsetAmount
            end

            if next(elements) ~= nil then
                imageCanvas:replaceElements(elements)
            end

            return imageCanvas:imageFromCanvas()
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
