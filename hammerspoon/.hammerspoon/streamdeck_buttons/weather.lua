require "streamdeck_buttons.button_images"
require "color_support"

-- from https://stackoverflow.com/questions/59561776/how-do-i-insert-a-string-into-another-string-in-lua
function string.insert(str1, str2, pos)
    return str1:sub(1,pos)..str2..str1:sub(pos+1)
end

local function weatherButtonForLocation(location)
    return {
        ['name'] = 'Weather',
        ['imageProvider'] = function()
            local url = "wttr.in?format=1"
            if location ~= nil then
                url = "wttr.in/" .. location
                url = url .. "?format=1"
            end
            local command = 'curl -s ' .. url
            command = command .. '| sed "s/+//" | sed "s/F//" | grep -v "Unknow"'
            local output = hs.execute(command)
            local justTemperature = output:gsub('%W', '')
            justTemperature = tonumber(justTemperature)
            local backgroundColor = hs.drawing.color.black
            local textColor = hs.drawing.color.white
            if justTemperature ~= nil then
                local value = tonumber(justTemperature) / 100.0
                local backgroundColor = colorBetween(hs.drawing.color.blue, hs.drawing.color.red, value)
            else
                output = "?"
                textColor = hs.drawing.color.white
                backgroundColor = hs.drawing.color.black
            end
            local fontSize = 40
            if location ~= nil then
                output = location .. '\n' .. output
                fontSize = 24
            end
            local options = {
                ['backgroundColor'] = backgroundColor,
                ['textColor'] = textColor,
                ['fontSize'] = fontSize
            }
            return streamdeck_imageFromText(output, options)
        end,
        ['updateInterval'] = 1800,
    }
end

function weatherButton()
    local button = weatherButtonForLocation(nil)
    button['children'] = function()
        return {
            weatherButtonForLocation('LA'),
            weatherButtonForLocation('NYC'),
            weatherButtonForLocation('Denver'),
            weatherButtonForLocation('MN'),
            weatherButtonForLocation('London'),
            weatherButtonForLocation('Sydney'),
            weatherButtonForLocation('Honolulu')
        }
    end
    return button
end

