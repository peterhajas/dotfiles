function dictationButton()
    local function refresh()
        require("streamdeck"):updateButton('Dictation')
    end

    return {
        ['name'] = 'Dictation',
        ['imageProvider'] = function()
            local glyph = dictation.isDictating() and '􀊰' or '􀊱'
            return streamdeck_imageFromText(glyph)
        end,
        ['onPress'] = function()
            -- Tap or push-to-talk both start by toggling on press.
            dictation.toggle()
            refresh()
        end,
        ['onLongPress'] = function(holding)
            -- Push-to-talk: release toggles back off.
            if not holding then
                dictation.toggle()
                refresh()
            end
        end,
        ['updateInterval'] = 5,
    }
end
