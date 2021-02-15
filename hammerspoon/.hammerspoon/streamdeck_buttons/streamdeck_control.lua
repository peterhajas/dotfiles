require "streamdeck_buttons.button_images"
function streamdeckControl()
    return {
        ['image'] = streamdeck_imageFromText('􀦴'),
        ['children'] = {
            {
                ['image'] = streamdeck_imageFromText('􀆫'),
                ['pressUp'] = function(deck) 
                    
                end
            }
        }
    }
end
