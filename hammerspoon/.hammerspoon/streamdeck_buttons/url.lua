require "streamdeck_buttons.button_images"
require "color_support"

local function urlButton(url, button)
    local out = button
    out['pressUp'] =  function()
        hs.urlevent.openURL(url)
        performAfter = performAfter or function() end
        hs.timer.doAfter(0.2, function()
            performAfter()
        end)
    end
    return out
end

weatherButton = urlButton('https://wttr.in', {
    ['imageProvider'] = function()
        local output = hs.execute('curl -s "wttr.in?format=1" | sed "s/+//" | sed "s/F//" | grep -v "Unknow"')
        local justTemperature = output:gsub('%W', '')
        justTemperature = tonumber(justTemperature)
        local backgroundColor = hs.drawing.color.black
        local textColor = hs.drawing.color.black
        if justTemperature ~= nil then
            local value = tonumber(justTemperature) / 100.0
            local backgroundColor = colorBetween(hs.drawing.color.blue, hs.drawing.color.red, value)
        else
            output = "?"
            textColor = hs.drawing.color.white
            backgroundColor = hs.drawing.color.black
        end
        local options = {
            ['backgroundColor'] = backgroundColor,
            ['textColor'] = textColor,
            ['fontSize'] = 40
        }
        return streamdeck_imageFromText(output, options)
    end,
    ['updateInterval'] = 60,
})

