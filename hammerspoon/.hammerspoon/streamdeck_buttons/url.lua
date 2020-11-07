require "streamdeck_buttons.button_images"

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
        return streamdeck_imageFromText(output, {['fontSize'] = 40 })
    end,
    ['updateInterval'] = 60 * 60 * 10,
})

