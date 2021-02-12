require "streamdeck_buttons.button_images"

local fraction = 0
local goingUp = true
local step = 0.01
animation_demo = {
    ['imageProvider'] = function(pressed)
        local bg = colorBetween(hs.drawing.color.blue, hs.drawing.color.red, fraction)
        local options = {
            ['backgroundColor'] = bg,
            ['fontSize'] = 20
        }
        if goingUp then
            fraction = fraction + step
        else
            fraction = fraction - step
        end
        if fraction >= 1 then
            goingUp = false
        end
        if fraction <= 0 then
            goingUp = true
        end
        return streamdeck_imageFromText(fraction, options)
    end,
    ['updateInterval'] = 0.2
}
