require "darkmode"
require "util"

-- System Colors
systemYellowColor = nil
systemBlueColor = nil
systemGreenColor = nil
systemRedColor = nil
systemOrangeColor = nil

-- Semantic
systemTextColor = nil
systemBackgroundColor = nil

-- Other Colors
tintColor = nil
function randomColor()
    return {
        ['hue'] = math.random(255.0) / 255.0,
        ['saturation'] = math.random(2, 10) / 10,
        ['brightness'] = 1.0,
        ['alpha'] = 1.0
    }
end

local function updateThemeColors()
    systemYellowColor = hs.drawing.color.lists()['System']['systemYellowColor']
    systemBlueColor = hs.drawing.color.lists()['System']['systemBlueColor']
    systemGreenColor = hs.drawing.color.lists()['System']['systemGreenColor']
    systemRedColor = hs.drawing.color.lists()['System']['systemRedColor']
    systemOrangeColor = hs.drawing.color.lists()['System']['systemOrangeColor']

    systemTextColor = hs.drawing.color.lists()['System']['textColor']

    -- Bit of a hack for now
    tintColor = systemOrangeColor
end

updateThemeColors()

