require "streamdeck_buttons.button_images"
require "terminal"

local function terminalButton(commandProvider, button)
    local out = button
    out['pressUp'] = function()
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

