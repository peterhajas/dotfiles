require "color_support"
require "terminal"

local function terminalButton(commandProvider, button)
    local out = button
    out['onClick'] = function()
        local command = commandProvider()
        if command == nil then
            return
        end

        runInNewTerminal(command)

        performAfter = button['performAfter'] or function() end
        hs.timer.doAfter(0.1, function()
            performAfter()
        end)
    end
    return out
end

cpuButton = terminalButton(function() return 'htop' end, {
    ['imageProvider'] = function()
        local value = math.floor(hs.execute('cpu_usage.sh', true))
        local text = "🖥️" .. value .. "%"
        local color = severityColorForFraction(value/100.0)
        local options = {
            ['backgroundColor'] = color,
            ['textColor'] = hs.drawing.color.black,
            ['fontSize'] = 40
        }
        return streamdeck_imageFromText(text, options)
    end,
    ['performAfter'] = function()
        hs.eventtap.keyStrokes("P")
    end,
    ['updateInterval'] = 10,
})

memoryButton = terminalButton(function() return 'htop' end, {
    ['imageProvider'] = function()
        local value = math.floor(hs.execute('mem_usage.sh', true))
        local text = "🧠" .. value .. "%"
        local color = severityColorForFraction(value/100.0)
        local options = {
            ['backgroundColor'] = color,
            ['textColor'] = hs.drawing.color.black,
            ['fontSize'] = 40
        }
        return streamdeck_imageFromText(text, options)
    end,
    ['performAfter'] = function()
        hs.eventtap.keyStrokes("M")
    end,
    ['updateInterval'] = 10,
})

