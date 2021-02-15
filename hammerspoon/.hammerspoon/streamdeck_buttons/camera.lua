camera1Button = {
    ['name'] = 'Camera 1',
    ['imageProvider'] = function()
        return hs.image.imageFromURL("http://192.168.0.167/cgi-bin/currentpic.cgi")
    end,
    ['updateInterval'] = 30
}

camera2Button = {
    ['name'] = 'Camera 2',
    ['imageProvider'] = function()
        return hs.image.imageFromURL("http://192.168.0.196/cgi-bin/currentpic.cgi")
    end,
    ['updateInterval'] = 30
}
