require "colors"
require "streamdeck_buttons.button_images"

-- A nonce button
function nonceButton()
    return {
        ['name'] = 'Nonce',
        ['imageProvider'] = function(context)
            local options = { }
            if context['isPressed'] then
                options = { ['backgroundColor'] = tintColor }
            end
            return streamdeck_imageFromText('', options)
        end
    }
end
