require "streamdeck_buttons.button_images"

monthButton = {
    ['imageProvider'] = function()
        return streamdeck_imageFromText(os.date("%b"))
    end,
    ['updateInterval'] = 3600
}

dayButton = {
    ['imageProvider'] = function()
        return streamdeck_imageFromText(os.date("%d"))
    end,
    ['updateInterval'] = 3600
}

clockButton = {
    ['imageProvider'] = function()
        return streamdeck_imageFromText(os.date("%I:%M"), { ['fontSize'] = 30 })
    end,
    ['updateInterval'] = 30
}
