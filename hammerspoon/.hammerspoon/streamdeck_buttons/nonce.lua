require "colors"
require "streamdeck_buttons.button_images"

-- A nonce button
function nonceButton()
    return {
        ['name'] = 'Nonce',
        ['imageProvider'] = function(context)
            local inset = 24
            local radius = 8
            local color = systemBackgroundColor
            if not context['isPressed'] then
                color = randomColor() 
            end

            local elements = { }
            table.insert(elements, {
                action = "fill",
                frame = { x = inset, y = inset, w = buttonWidth - 2 * inset, h = buttonHeight - 2 * inset },
                type = "rectangle",
                fillColor = color,
                roundedRectRadii = { ["xRadius"] = radius, ["yRadius"] = radius },
            })
            return streamdeck_imageWithCanvasContents(elements)
        end,
        ['updateInterval'] = 5,
    }
end
