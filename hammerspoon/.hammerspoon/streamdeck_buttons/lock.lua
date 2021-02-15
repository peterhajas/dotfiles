lockButton = {
    ['name'] = 'Lock',
    ['image'] = streamdeck_imageFromText('􀎡'),
    ['pressUp'] = function()
        hs.caffeinate.lockScreen()
    end
}
