require "itunes_albumart"
require "streamdeck_buttons.button_images"

function itunesPreviousButton()
    return {
        ['image'] = streamdeck_imageFromText("􀊊"),
        ['pressUp'] = function()
            hs.itunes.previous()
        end
    }
end

function itunesNextButton()
    return {
        ['image'] = streamdeck_imageFromText("􀊌"),
        ['pressUp'] = function()
            hs.itunes.next()
        end
    }
end

function itunesPlayPuaseButton()
    return {
        ['imageProvider'] = function (pressed)
            return streamdeck_imageFromText("􀊄")
        end,
        ['pressUp'] = function()
            hs.itunes.playpause()
        end,
        ['updateInterval'] = 10,
    }
end

