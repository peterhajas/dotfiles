require "streamdeck_buttons.button_images"

local function urlButton(url, button)
    local out = button
    out['pressUp'] = function()
        hs.urlevent.openURL(url)
        performAfter = performAfter or function() end
        hs.timer.doAfter(0.2, function()
            performAfter()
        end)
    end
    return out
end

