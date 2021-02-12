require "streamdeck_buttons.button_images"

-- Key: bundleID
-- Value: last "press down" nanoseconds
local peekDownTimes = {}
function peekButtonFor(bundleID)
    return {
        ['name'] = "Peek " .. bundleID,
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

local calendarButtonDimension = 76

function calendarPeekButton()
    local button = peekButtonFor('com.apple.iCal')

    local x = (buttonWidth - calendarButtonDimension)/2
    local y = (buttonHeight - calendarButtonDimension)/2

    local radius = 16
    local headerHeight = 24

    local headerFontSize = 16
    local bodyFontSize = 42

    local headerText = os.date("%b")
    -- +0 to strip leading 0
    local bodyText = os.date("%d") + 0

    button['image'] = nil
    button['imageProvider'] = function(pressed)
        local imageCanvas = hs.canvas.new{ w = buttonWidth, h = buttonHeight }

        -- White background
        imageCanvas[1] = {
            action = "fill",
            frame = { x = x, y = y, w = calendarButtonDimension, h = calendarButtonDimension },
            fillColor = hs.drawing.color.white,
            type = "rectangle",
        }

        -- Red header
        imageCanvas[2] = {
            action = "fill",
            frame = { x = x, y = y, w = calendarButtonDimension, h = headerHeight },
            fillColor = { red = 249.0/255.0, green = 86.0/255.0, blue = 78.0/255.0, alpha = 1.0},
            type = "rectangle"
        }

        -- Header text
        imageCanvas[3] = {
            frame = { x = x, y = y, w = calendarButtonDimension, h = headerHeight },
            text = hs.styledtext.new(headerText, {
                font = { name = ".AppleSystemUIFont", size = headerFontSize },
                paragraphStyle = { alignment = "center" },
                color = hs.drawing.color.white,
            }),
            type = "text"
        }

        -- Body text
        imageCanvas[4] = {
            frame = { x = x, y = y + headerHeight, w = calendarButtonDimension, h = calendarButtonDimension - headerHeight },
            text = hs.styledtext.new(bodyText, {
                font = { name = ".AppleSystemUIFont", size = bodyFontSize },
                paragraphStyle = { alignment = "center" },
                color = hs.drawing.color.black,
            }),
            type = "text"
        }

        -- Clip
        -- This doesn't work, and I don't know why
        imageCanvas[5] = {
            action = "clip",
            frame = { x = x, y = y, w = calendarButtonDimension, h = calendarButtonDimension },
            roundedRectRadii = { xRadius = radius, yRadius = radius },
            type = "rectangle",
        }

        return imageCanvas:imageFromCanvas()
    end
    button['updateInterval'] = 3600
    return button
end

