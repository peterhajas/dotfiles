-- A nonce button
local button_images = require("streamdeck.button_images")

local M = {}

function M.nonceButton()
    return {
        ['name'] = 'Nonce',
        ['imageProvider'] = function(context)
            local inset = 24
            local radius = 8
            local color = randomColor()
            local background = systemBackgroundColor
            if context['isPressed'] then
                background = color
                color = systemBackgroundColor
            end

            local elements = { }
            table.insert(elements, {
                action = "fill",
                frame = { x = 0, y = 0, w = button_images.buttonWidth, h = button_images.buttonHeight },
                fillColor = background,
                type = "rectangle",
            })
            table.insert(elements, {
                action = "fill",
                frame = { x = inset, y = inset, w = button_images.buttonWidth - 2 * inset, h = button_images.buttonHeight - 2 * inset },
                type = "rectangle",
                fillColor = color,
                roundedRectRadii = { ["xRadius"] = radius, ["yRadius"] = radius },
            })
            return button_images.imageWithCanvasContents(elements)
        end,
        ['updateInterval'] = 5,
    }
end

return M
