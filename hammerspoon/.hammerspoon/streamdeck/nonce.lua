-- A nonce button
function nonceButton()
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
                frame = { x = 0, y = 0, w = buttonWidth, h = buttonHeight },
                fillColor = background,
                type = "rectangle",
            })
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
