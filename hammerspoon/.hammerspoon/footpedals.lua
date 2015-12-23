-- vim:fdm=marker
-- Frontmost app {{{

function frontmostAppName ()
    return hs.application.frontmostApplication():title()
end

-- }}}
-- Footpedals Key Combos {{{

-- My footpedals map to F9 and F10. We'll use this to make different things
-- happen in different apps

local footpedalKeyCombos = {}

-- Footpedal Key Combos are defined as a table of tables
-- Each entry in the table has the modifiers (if any), the left key pedal press,
-- and the right key pedal press.
--
-- Most apps only have one command per foot. Some, like Mail, require two

footpedalKeyCombos["Mail"]     = { {{"cmd","shift"}, "k", "k"}, {{}, "up", "down"} }
footpedalKeyCombos["Safari"]   = { {{"cmd","shift"}, "[", "]" } }
footpedalKeyCombos["Tweetbot"] = { {{"cmd"}, "[", "]" } }
footpedalKeyCombos["iTunes"]   = { {{"cmd"}, "left", "right" } }
footpedalKeyCombos["Photos"]   = { {{"cmd"}, "left", "right" } }
footpedalKeyCombos["Messages"] = { {{"cmd"}, "[", "]" } }
footpedalKeyCombos["Calendar"] = { {{"cmd"}, "left", "right" } }

-- }}}
-- Sending footpedal key commands {{{

function sendKeyStroke(modifiers, character)
    hs.eventtap.keyStroke(modifiers, character)
end


function runFootpedalCommandsForFoot(commands, foot)
    if commands == nil then return end
    for idx,command in pairs(commands) do
        local modifiers = command[1]
        local key

        if foot == "left" then
            key = command[2]
        else
            key = command[3]
        end

        sendKeyStroke(modifiers, key)
    end
end

hs.hotkey.bind({""}, "f9", function()
    runFootpedalCommandsForFoot(footpedalKeyCombos[frontmostAppName()], "left")
end)

hs.hotkey.bind({""}, "f10", function()
    runFootpedalCommandsForFoot(footpedalKeyCombos[frontmostAppName()], "right")
end)

-- }}}
