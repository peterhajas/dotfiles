require "streamdeck_buttons.button_images"

-- curl -X POST --data '{"actionName": "Office Toggle"}' -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiI3MGRiZTVhMGZmZGU0MTFhOTY5MzI0NjM0YTYzNmY5YyIsImlhdCI6MTYxMDYwODIxNiwiZXhwIjoxOTI1OTY4MjE2fQ.cLQX5-u71GgxlGkXXVXSpt0ZQ4IS9Kz9coqAVXbefHw" -H "Content-Type: application/json" "http://lighthouse.local:8123/api/events/ios.action_fired"	

local imageOptions = {
    ['textColor'] = hs.drawing.color.black,
    ['backgroundColor'] = hs.drawing.color.white
}

officeToggle = {
    ['image'] = streamdeck_imageFromText("􀛮", imageOptions),
    ['pressUp'] = function()
        -- This posts the same event that my iOS / watch action does
        hs.execute('curl -X POST --data \'{"actionName": "Office Toggle"}\' -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiI3MGRiZTVhMGZmZGU0MTFhOTY5MzI0NjM0YTYzNmY5YyIsImlhdCI6MTYxMDYwODIxNiwiZXhwIjoxOTI1OTY4MjE2fQ.cLQX5-u71GgxlGkXXVXSpt0ZQ4IS9Kz9coqAVXbefHw" -H "Content-Type: application/json" "http://lighthouse.local:8123/api/events/ios.action_fired"')
    end
}
