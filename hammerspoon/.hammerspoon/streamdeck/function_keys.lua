local function fKeyForNumber(number)
    return {
        ['name'] = 'F' .. number,
        ['image'] = streamdeck_imageFromText('F'..number, { ['fontSize'] = 50 }),
        ['onClick'] = function()
            local keycode = 'f' .. number
            hs.eventtap.keyStroke({'fn'}, keycode)
        end
    }
end

function functionKeys()
    return {
        ['name'] = "Function Keys",
        ['image'] = streamdeck_imageFromText("􀅮"),
        ['children'] = function()
            local children = {}
            local count = 20
            for i = 0,count-1,1 do
                table.insert(children, fKeyForNumber(i+1))
            end
            return children
        end
    }
end
