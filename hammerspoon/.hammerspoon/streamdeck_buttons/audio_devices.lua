require "streamdeck_buttons.button_images"

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
            local text = ""
            if input then
                text = "􀊱\n" .. deviceName
            else
                text = "􀊩\n" .. deviceName
            end
            return streamdeck_imageFromText(text, { ['fontSize'] = 25 })
        end,
        ['pressUp'] = function()
            local currentDeviceName = hs.audiodevice.current(input)['name']

            local allDevices = { }
            if input then
                allDevices = hs.audiodevice.allInputDevices()
            else
                allDevices = hs.audiodevice.allOutputDevices()
            end

            local index = -1
            local count = 0

            for k,v in pairs(allDevices) do
                if v:name() == currentDeviceName then
                    index = k
                end
                count = count + 1
            end

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
