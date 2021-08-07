clockButton = {
    ['name'] = 'Clock',
    ['imageProvider'] = function()
        return streamdeck_imageFromText(os.date("%H:%M"), { ['fontSize'] = 30 })
    end,
    ['updateInterval'] = 30
}
