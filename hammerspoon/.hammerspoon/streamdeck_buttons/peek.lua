require "streamdeck_buttons.button_images"

-- Key: bundleID
-- Value: last "press down" nanoseconds
local peekDownTimes = {}
function peekButtonFor(bundleID)
    return {
        ['image'] = hs.image.imageFromAppBundle(bundleID),
        ['pressDown'] = function()
            local app = hs.application.get(bundleID)
            local shouldLaunch = true
            if app ~= nil then
                if app:isFrontmost() then
                    shouldLaunch = false
                    app:hide()
                end
            end
            if shouldLaunch then
                hs.application.open(bundleID)
            end
            peekDownTimes[bundleID] = hs.timer.absoluteTime()
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

