require "streamdeck_buttons.button_images"

function numpad()
    return {
        ['image'] = streamdeck_imageFromText('􀃫'),
        ['children'] = function()
            return {}
        end
    }
end
