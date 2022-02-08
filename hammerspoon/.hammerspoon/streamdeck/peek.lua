function peekButtonFor(bundleID)
    return {
        ['name'] = "Peek " .. bundleID,
        ['image'] = hs.image.imageFromAppBundle(bundleID),
        ['onClick'] = function()
            local app = hs.application.get(bundleID)
            if app == nil then
                hs.application.open(bundleID)
                return
            end
            if app:isRunning() then
                if app:isFrontmost() then
                    app:hide()
                else
                    hs.application.open(bundleID)
                    app:activate()
                end
            else
                hs.application.open(bundleID)
            end
        end,
        ['onLongPress'] = function(holding)
            local app = hs.application.get(bundleID)
            if app == nil then
                hs.application.open(bundleID)
                return
            end
            if holding then
                hs.application.open(bundleID)
                if app:isRunning() then
                    app:activate()
                end
            else
                if app:isRunning() then
                    app:hide()
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
    button['stateProvider'] = function()
        return os.date("%d") + 0
    end
    button['imageProvider'] = function(state)
        local elements = {}

        -- White background
        table.insert(elements, {
            action = "fill",
            frame = { x = x, y = y, w = calendarButtonDimension, h = calendarButtonDimension },
            fillColor = hs.drawing.color.white,
            type = "rectangle",
        })

        -- Red header
        table.insert(elements, {
            action = "fill",
            frame = { x = x, y = y, w = calendarButtonDimension, h = headerHeight },
            fillColor = { red = 249.0/255.0, green = 86.0/255.0, blue = 78.0/255.0, alpha = 1.0},
            type = "rectangle"
        })

        -- Header text
        table.insert(elements, {
            frame = { x = x, y = y, w = calendarButtonDimension, h = headerHeight },
            text = hs.styledtext.new(headerText, {
                font = { name = ".AppleSystemUIFont", size = headerFontSize },
                paragraphStyle = { alignment = "center" },
                color = hs.drawing.color.white,
            }),
            type = "text"
        })

        -- Body text
        table.insert(elements, {
            frame = { x = x, y = y + headerHeight, w = calendarButtonDimension, h = calendarButtonDimension - headerHeight },
            text = hs.styledtext.new(bodyText, {
                font = { name = ".AppleSystemUIFont", size = bodyFontSize },
                paragraphStyle = { alignment = "center" },
                color = hs.drawing.color.black,
            }),
            type = "text"
        })

        -- Clip
        -- This doesn't work, and I don't know why
        table.insert(elements, {
            action = "clip",
            frame = { x = x, y = y, w = calendarButtonDimension, h = calendarButtonDimension },
            roundedRectRadii = { xRadius = radius, yRadius = radius },
            type = "rectangle",
        })

        return streamdeck_imageWithCanvasContents(elements)
    end
    button['updateInterval'] = 60
    return button
end

