require "darkmode"
require "util"

-- System Colors
alternateSelectedControlTextColor = nil
alternatingContentBackgroundColor = nil
controlAccentColor = nil
controlBackgroundColor = nil
controlColor = nil
controlTextColor = nil
disabledControlTextColor = nil
findHighlightColor = nil
gridColor = nil
headerTextColor = nil
keyboardFocusIndicatorColor = nil
labelColor = nil
linkColor = nil
placeholderTextColor = nil
quaternaryLabelColor = nil
secondaryLabelColor = nil
selectedContentBackgroundColor = nil
selectedControlColor = nil
selectedControlTextColor = nil
selectedMenuItemTextColor = nil
selectedTextBackgroundColor = nil
selectedTextColor = nil
separatorColor = nil
systemBlueColor = nil
systemBrownColor = nil
systemGrayColor = nil
systemGreenColor = nil
systemIndigoColor = nil
systemOrangeColor = nil
systemPinkColor = nil
systemPurpleColor = nil
systemRedColor = nil
systemTealColor = nil
systemYellowColor = nil
tertiaryLabelColor = nil
textBackgroundColor = nil
textColor = nil
underPageBackgroundColor = nil
unemphasizedSelectedContentBackgroundColor = nil
unemphasizedSelectedTextBackgroundColor = nil
unemphasizedSelectedTextColor = nil
windowBackgroundColor = nil
windowFrameTextColor = nil

-- Other Colors
tintColor = nil
systemBackgroundColor = nil
systemTextColor = nil
function randomColor()
    return {
        ['hue'] = math.random(255.0) / 255.0,
        ['saturation'] = math.random(2, 10) / 10,
        ['brightness'] = 1.0,
        ['alpha'] = 1.0
    }
end

local function updateThemeColors()
    alternateSelectedControlTextColor = hs.drawing.color.lists()['System']['alternateSelectedControlTextColor']
    alternatingContentBackgroundColor = hs.drawing.color.lists()['System']['alternatingContentBackgroundColor']
    controlAccentColor = hs.drawing.color.lists()['System']['controlAccentColor']
    controlBackgroundColor = hs.drawing.color.lists()['System']['controlBackgroundColor']
    controlColor = hs.drawing.color.lists()['System']['controlColor']
    controlTextColor = hs.drawing.color.lists()['System']['controlTextColor']
    disabledControlTextColor = hs.drawing.color.lists()['System']['disabledControlTextColor']
    findHighlightColor = hs.drawing.color.lists()['System']['findHighlightColor']
    gridColor = hs.drawing.color.lists()['System']['gridColor']
    headerTextColor = hs.drawing.color.lists()['System']['headerTextColor']
    keyboardFocusIndicatorColor = hs.drawing.color.lists()['System']['keyboardFocusIndicatorColor']
    labelColor = hs.drawing.color.lists()['System']['labelColor']
    linkColor = hs.drawing.color.lists()['System']['linkColor']
    placeholderTextColor = hs.drawing.color.lists()['System']['placeholderTextColor']
    quaternaryLabelColor = hs.drawing.color.lists()['System']['quaternaryLabelColor']
    secondaryLabelColor = hs.drawing.color.lists()['System']['secondaryLabelColor']
    selectedContentBackgroundColor = hs.drawing.color.lists()['System']['selectedContentBackgroundColor']
    selectedControlColor = hs.drawing.color.lists()['System']['selectedControlColor']
    selectedControlTextColor = hs.drawing.color.lists()['System']['selectedControlTextColor']
    selectedMenuItemTextColor = hs.drawing.color.lists()['System']['selectedMenuItemTextColor']
    selectedTextBackgroundColor = hs.drawing.color.lists()['System']['selectedTextBackgroundColor']
    selectedTextColor = hs.drawing.color.lists()['System']['selectedTextColor']
    separatorColor = hs.drawing.color.lists()['System']['separatorColor']
    systemBlueColor = hs.drawing.color.lists()['System']['systemBlueColor']
    systemBrownColor = hs.drawing.color.lists()['System']['systemBrownColor']
    systemGrayColor = hs.drawing.color.lists()['System']['systemGrayColor']
    systemGreenColor = hs.drawing.color.lists()['System']['systemGreenColor']
    systemIndigoColor = hs.drawing.color.lists()['System']['systemIndigoColor']
    systemOrangeColor = hs.drawing.color.lists()['System']['systemOrangeColor']
    systemPinkColor = hs.drawing.color.lists()['System']['systemPinkColor']
    systemPurpleColor = hs.drawing.color.lists()['System']['systemPurpleColor']
    systemRedColor = hs.drawing.color.lists()['System']['systemRedColor']
    systemTealColor = hs.drawing.color.lists()['System']['systemTealColor']
    systemYellowColor = hs.drawing.color.lists()['System']['systemYellowColor']
    tertiaryLabelColor = hs.drawing.color.lists()['System']['tertiaryLabelColor']
    textBackgroundColor = hs.drawing.color.lists()['System']['textBackgroundColor']
    textColor = hs.drawing.color.lists()['System']['textColor']
    underPageBackgroundColor = hs.drawing.color.lists()['System']['underPageBackgroundColor']
    unemphasizedSelectedContentBackgroundColor = hs.drawing.color.lists()['System']['unemphasizedSelectedContentBackgroundColor']
    unemphasizedSelectedTextBackgroundColor = hs.drawing.color.lists()['System']['unemphasizedSelectedTextBackgroundColor']
    unemphasizedSelectedTextColor = hs.drawing.color.lists()['System']['unemphasizedSelectedTextColor']
    windowBackgroundColor = hs.drawing.color.lists()['System']['windowBackgroundColor']
    windowFrameTextColor = hs.drawing.color.lists()['System']['windowFrameTextColor']

    tintColor = systemOrangeColor
    systemBackgroundColor = windowBackgroundColor
    systemTextColor = textColorlabelColor
end

updateThemeColors()

