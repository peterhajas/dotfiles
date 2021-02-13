require "streamdeck_buttons.button_images"
require("home_assistant")

local imageOptions = {
    ['textColor'] = hs.drawing.color.black,
    ['backgroundColor'] = hs.drawing.color.white
}

officeToggle = {
    ['image'] = streamdeck_imageFromText("􀛮", imageOptions),
    ['pressUp'] = function()
        -- This posts the same event that my iOS / watch action does
        homeAssistantRun('POST', 'events/ios.action_fired', { ['actionName'] = 'Office Toggle' })
    end
}

