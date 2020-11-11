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
        local value = tonumber(justTemperature) / 100.0
        local color = colorBetween(hs.drawing.color.blue, hs.drawing.color.red, value)
        local options = {
            ['backgroundColor'] = color,
            ['textColor'] = hs.drawing.color.black,
            ['fontSize'] = 40
        }
        return streamdeck_imageFromText(output, options)
    end,
    ['updateInterval'] = 60 * 60 * 10,
})

