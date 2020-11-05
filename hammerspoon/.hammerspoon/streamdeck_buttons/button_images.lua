buttonWidth = 96
buttonHeight = 96

-- Returns an image with the specified text, color, and background color
function streamdeck_imageFromText(text, options)
    local imageCanvas = hs.canvas.new{ w = buttonWidth, h = buttonHeight }
    local options = options or { }
    textColor = options['textColor'] or hs.drawing.color.white
    backgroundColor = options["backgroundColor"] or hs.drawing.color.black
    fontSize = options['fontSize'] or 70
    imageCanvas[1] = {
        action = "fill",
        frame = { x = 0, y = 0, w = buttonWidth, h = buttonHeight },
        fillColor = backgroundColor,
        type = "rectangle",
    }
    imageCanvas[2] = {
        frame = { x = 0, y = 0, w = buttonWidth, h = buttonHeight },
        text = hs.styledtext.new(text, {
            font = { name = ".AppleSystemUIFont", size = fontSize },
            paragraphStyle = { alignment = "center" },
            color = textColor,
        }),
        type = "text",
    }
    return imageCanvas:imageFromCanvas()
end
