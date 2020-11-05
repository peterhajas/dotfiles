require "streamdeck_buttons.button_images"

clockButton = {
    ['imageProvider'] = function()
        return streamdeck_imageFromText(os.date("%I:%M"), { ['fontSize'] = 30 })
    end,
    ['updateInterval'] = 30
}
