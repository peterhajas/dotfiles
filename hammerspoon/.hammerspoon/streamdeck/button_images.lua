require "colors"

local M = {}

M.buttonWidth = 96
M.buttonHeight = 96

-- Shared cached canvas
local sharedCanvas = hs.canvas.new{ w = M.buttonWidth, h = M.buttonHeight }

-- Returns an image with the specified canvas contents
-- Canvas contents are a table of canvas commands
function M.imageWithCanvasContents(contents)
    sharedCanvas:replaceElements(contents)
    return sharedCanvas:imageFromCanvas()
end

-- Returns an image with the specified text, color, and background color
function M.imageFromText(text, options)
    local options = options or { }
    textColor = options['textColor'] or tintColor
    backgroundColor = options["backgroundColor"] or systemBackgroundColor
    font = options['font'] or ".AppleSystemUIFont"
    fontSize = options['fontSize'] or 70
    local elements = { }
    table.insert(elements, {
        action = "fill",
        frame = { x = 0, y = 0, w = M.buttonWidth, h = M.buttonHeight },
        fillColor = backgroundColor,
        type = "rectangle",
    })
    table.insert(elements, {
        frame = { x = 0, y = 0, w = M.buttonWidth, h = M.buttonHeight },
        text = hs.styledtext.new(text, {
            font = { name = font, size = fontSize },
            paragraphStyle = { alignment = "center" },
            color = textColor,
        }),
        type = "text",
    })
    return M.imageWithCanvasContents(elements)
end

return M
