require "colors"
require "streamdeck_buttons.button_images"

-- A nonce button
function nonceButton()
    return {
        ['name'] = 'Nonce',
        ['imageProvider'] = function(context)
            local options = { }
            local color = systemBackgroundColor
            if not context['isPressed'] then
                color = randomColor() 
            end
            local options = {
                ['backgroundColor'] = color
            }
            return streamdeck_imageFromText('', options)
        end,
        ['updateInterval'] = 5,
    }
end
