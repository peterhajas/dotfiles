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
    -- This draws a button with a list of devices in it
    local name = "audio_"
    if input then
        name = name .. 'input'
    else
        name = name .. 'output'
    end
    return {
        ['stateProvider'] = function ()
            return {
                ['name'] = hs.audiodevice.current(input)['name'],
                ['indexCount'] = indexAndCountOfAudioDevices(input),
                ['volume'] = hs.audiodevice.current(input)['volume'],
            }
        end,
        ['imageProvider'] = function (context)
            local currentDeviceName = context['state']['name']
            local volume = context['state']['volume']

            local elements = { }
            table.insert(elements, {
                action = "fill",
                frame = { x = 0, y = 0, w = buttonWidth, h = buttonHeight },
                fillColor = systemBackgroundColor,
                type = "rectangle",
            })

            local volumeIndicatorYOffset = 0
            local volumeIndicatorWidth = buttonWidth
            local volumeIndicatorColor = cloneTable(tintColor)

            if volume ~= nil then
                volumeIndicatorWidth = volume * buttonWidth * 0.01
            else
                volumeIndicatorColor['alpha'] = 0.4
            end
            
            table.insert(elements, {
                action = "fill",
                frame = { x = 0,
                          y = 0,
                          w = volumeIndicatorWidth,
                          h = 5 },
                fillColor = volumeIndicatorColor,
                type = "rectangle",
            })

            local yOffset = 10
            local fontSize = 14
            local yOffsetAmount = 13

            for k,v in pairs(allAudioDevices(input)) do
                local text = empty
                local color = secondaryLabelColor
                if v:name() == currentDeviceName then
                    text = full
                    color = tintColor
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

            return streamdeck_imageWithCanvasContents(elements)
        end,
        ['onClick'] = function()
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
        ['updateInterval'] = 30, -- The watcher that updates us isn't called when volume changes
    }
end
