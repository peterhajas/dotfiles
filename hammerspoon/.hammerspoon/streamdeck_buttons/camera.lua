camera1Button = {
    ['imageProvider'] = function()
        return hs.image.imageFromURL("http://192.168.0.167/cgi-bin/currentpic.cgi")
    end,
    ['updateInterval'] = 30
}

camera2Button = {
    ['imageProvider'] = function()
        return hs.image.imageFromURL("http://192.168.0.196/cgi-bin/currentpic.cgi")
    end,
    ['updateInterval'] = 30
}
