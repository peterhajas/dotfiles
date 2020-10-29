require "streamdeck_buttons.button_images"

-- Key: bundleID
-- Value: last "press down" nanoseconds
local peekDownTimes = {}
function peekButtonFor(bundleID)
    return {
        ['image'] = hs.image.imageFromAppBundle(bundleID),
        ['pressDown'] = function()
            peekDownTimes[bundleID] = hs.timer.absoluteTime()
            hs.application.open(bundleID)
        end,
        ['pressUp'] = function()
            local upTime = hs.timer.absoluteTime()
            local downTime = peekDownTimes[bundleID]

            if downTime ~= nil then
                local elapsed = (upTime - downTime) * .000001
                -- If we've held the button down for > 300ms, hide
                if elapsed > 300 then
                    local app = hs.application.get(bundleID)
                    if app ~= nil then
                        app:hide()
                    end
                end
            end
        end
    }
end

