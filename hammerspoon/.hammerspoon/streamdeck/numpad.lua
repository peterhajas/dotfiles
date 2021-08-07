require "streamdeck.util.panel"

local function numberFor(context)
    local x = context['location']['x']
    local y = context['location']['y']
    local w = context['size']['w']
    local h = context['size']['h']

    -- Put numbers in the far-right area, with a column of padding
    local numberStartX = w - 4
    local numberEndX = w - 1
    local numberStartY = 0
    local numberEndY = 3

    local numberX = x - numberStartX
    local numberY = y - numberStartY

    -- Check for 1-9
    local isNumber = x >= numberStartX
    and x < numberEndX
    and y >= numberStartY
    and y < numberEndY
    if isNumber then
        -- Flip vertically
        numberY = 2 - numberY
        local number = numberX + 3 * numberY + 1
        return number
    end

    -- Check for 0
    if numberX == 0 and numberY == 3 then
        return 0
    end

    return nil
end

local function symbolFor(context)
    local x = context['location']['x']
    local y = context['location']['y']
    local w = context['size']['w']
    local h = context['size']['h']

    -- Symbols:
    -- . and enter in the bottom row
    -- /, *, -, + on the right
    
    local symbolStartX = w - 4
    local symbolX = x - symbolStartX

    if symbolX == 1 then
        return "."
    end
    if symbolX == 2 then
        return "return"
    end

    if symbolX == 3 then
        local symbols = {
            "/",
            "*",
            "-",
            "+"
        }
        return symbols[y+1]
    end
    
    return nil
end

local function keystrokeFor(context)
    local number = numberFor(context)
    if number ~= nil then
        return tostring(number)
    end
    local symbol = symbolFor(context)
    if symbol ~= nil then
        return symbol
    end
    return ""
end

local function button()
    return {
        ['imageProvider'] = function(context)
            local number = numberFor(context)
            local symbol = symbolFor(context)

            local text = ""
            local textColor = tintColor
            local backgroundColor = hs.drawing.color.black

            if number ~= nil then
                text = number
            elseif symbol ~= nil then
                textColor = hs.drawing.color.black
                backgroundColor = tintColor

                if symbol == 'return' then
                    symbol = '='
                    backgroundColor = systemBlueColor
                end
                if symbol == '/' then
                    symbol = '÷'
                end
                if symbol == '*' then
                    symbol = 'x'
                end
                text = symbol
            end
            local options = {
                ['textColor'] = textColor,
                ['backgroundColor'] = backgroundColor
            }
            return streamdeck_imageFromText(text, options)
        end,
        ['onClick'] = function(context)
            if keystrokeFor(context) == 'return' then
                hs.eventtap.keyStroke({}, "return")
            else
                hs.eventtap.keyStrokes(keystrokeFor(context))
            end
        end
    }
end

-- A numberpad. Works best on the XL streamdeck
function numberPad()
    return {
        ['name'] = 'Number Pad',
        ['image'] = streamdeck_imageFromText("􀆃"),
        ['children'] = function(context)
            return panelChildren(context, button())
        end,
    }
end
