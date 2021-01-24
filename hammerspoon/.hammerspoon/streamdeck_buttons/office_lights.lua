require "streamdeck_buttons.button_images"

local imageOptions = {
    ['textColor'] = hs.drawing.color.black,
    ['backgroundColor'] = hs.drawing.color.white
}

officeToggle = {
    ['image'] = streamdeck_imageFromText("􀛮", imageOptions),
    ['pressUp'] = function()
        -- This posts the same event that my iOS / watch action does
        hs.execute('/Users/phajas/bin/home_assistant_run.bash \'events/ios.action_fired\' \'{ "actionName" : "Office Toggle" }\'')
    end
}

officeNormal = {
    ['image'] = streamdeck_imageFromText("􀝓", imageOptions),
    ['pressUp'] = function()
        hs.execute('/Users/phajas/bin/home_assistant_run.bash \'services/scene/turn_on\' \'{ "entity_id" : "scene.office_regular" }\'')
    end
}

officeMood = {
    ['image'] = streamdeck_imageFromText("􀜍", imageOptions),
    ['pressUp'] = function()
        hs.execute('/Users/phajas/bin/home_assistant_run.bash \'services/scene/turn_on\' \'{ "entity_id" : "scene.office_mood" }\'')
    end
}

