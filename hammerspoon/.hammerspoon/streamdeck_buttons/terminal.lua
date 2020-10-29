require "streamdeck_buttons.button_images"

local function terminalButton(commandProvider, button)
    local out = button
    out['pressUp'] = function()
        local command = commandProvider()
        if command == nil then
            return
        end

        hs.application.open("com.apple.Terminal")
        hs.eventtap.keyStroke({"cmd"}, "n")
        hs.eventtap.keyStrokes(command)
        hs.eventtap.keyStroke({}, "return")

        performAfter = button['performAfter'] or function() end
        hs.timer.doAfter(0.1, function()
            performAfter()
        end)
    end
    return out
end

cpuButton = terminalButton(function() return 'htop' end, {
    ['imageProvider'] = function()
        local output = hs.execute('cpu.10s.sh', true)
        return streamdeck_imageFromText(output, {['fontSize'] = 40 })
    end,
    ['performAfter'] = function()
        hs.eventtap.keyStrokes("P")
    end,
    ['updateInterval'] = 10,
})

memoryButton = terminalButton(function() return 'htop' end, {
    ['imageProvider'] = function()
        local output = hs.execute('memory.10s.sh', true)
        return streamdeck_imageFromText(output, {['fontSize'] = 40 })
    end,
    ['performAfter'] = function()
        hs.eventtap.keyStrokes("M")
    end,
    ['updateInterval'] = 10,
})

youtubeDLButton = terminalButton(function()
    -- Grab pasteboard
    local pasteboard = hs.pasteboard.readString()
    if string.find(pasteboard, 'http') then
        local command = "ytd \""..pasteboard.."\""
        return command
    end
    return nil
end, {
    ['image'] = streamdeck_imageFromText('􀊚"', {['backgroundColor'] = hs.drawing.color.white, ['textColor'] = hs.drawing.color.red}),
    ['performAfter'] = function()
        hs.eventtap.keyStroke({"ctrl"}, "d")
    end
})

