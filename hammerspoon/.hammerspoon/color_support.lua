require "colors"

-- Lerps between `a` and `b` by `fraction`
function lerp(a, b, fraction)
    local range = b - a
    return a + (range * fraction)
end

-- Returns a color between the two colors at `fraction`
-- `fraction` is assumed to be in the range 0 to 1 (inclusive)
function colorBetween(color1, color2, fraction)
    local color1HSB = hs.drawing.color.asHSB(color1)
    local color2HSB = hs.drawing.color.asHSB(color2)

    local alpha = lerp(color1HSB['alpha'], color2HSB['alpha'], fraction)
    local brightness = lerp(color1HSB['brightness'], color2HSB['brightness'], fraction)
    local hue = lerp(color1HSB['hue'], color2HSB['hue'], fraction)
    local saturation = lerp(color1HSB['saturation'], color2HSB['saturation'], fraction)

    return {
        ['alpha'] = alpha,
        ['brightness'] = brightness,
        ['hue'] = hue,
        ['saturation'] = saturation,
    }
end

-- Returns a color mapping the floating point value from `fraction` to a
-- representative color. `fraction` is assumed to be in the range 0 to 1 (inc.)
function severityColorForFraction(fraction)
    local low = systemGreenColor
    local high = systemRedColor
    return colorBetween(low, high, fraction)
end
