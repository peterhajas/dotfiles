function animationDemo()
    local button = { }
    button = {
        ['name'] = "Animation Demo",
        ['imageProvider'] = function(pressed)
            local fraction = button['fraction']
            local goingUp = button['goingUp']
            local step = button['step']
            local bg = colorBetween(hs.drawing.color.blue, hs.drawing.color.red, fraction)
            local options = {
                ['backgroundColor'] = bg,
                ['fontSize'] = 20
            }
            if goingUp then
                fraction = fraction + step
            else
                fraction = fraction - step
            end
            if fraction >= 1 then
                goingUp = false
            end
            if fraction <= 0 then
                goingUp = true
            end

            button['fraction'] = fraction
            button['goingUp'] = goingUp

            return streamdeck_imageFromText("", options)
        end,
        ['updateInterval'] = 1.0 / 60.0,
        ['children'] = function()
            return {
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
                animationDemo(),
            }
        end
    }

    button['fraction'] = 0
    button['goingUp'] = true
    button['step'] = math.random() * (4.0 / 60)

    return button
end
