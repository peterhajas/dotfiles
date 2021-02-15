require "streamdeck_buttons.button_images"

-- A nonce button
function nonceButton()
    return {
        ['name'] = 'Nonce',
        ['imageProvider'] = function(pressed)
            local options = { }
            if pressed then
                options = { ['backgroundColor'] = hs.drawing.color.lists()['Apple']['Orange'] }
            end
            return streamdeck_imageFromText('', options)
        end
    }
end
