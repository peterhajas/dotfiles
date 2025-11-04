-- Footpedals Module
-- Maps F18/F19 footpedal presses to app-specific key commands

local footpedals = {}

-- Private helper functions

local function frontmostAppName()
    return hs.application.frontmostApplication():title()
end

local function sendKeyStroke(modifiers, character)
    hs.eventtap.keyStroke(modifiers, character)
end

local function runFootpedalCommandsForFoot(commands, foot)
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

-- Footpedal Key Combos are defined as a table of tables
-- Each entry in the table has the modifiers (if any), the left key pedal press,
-- and the right key pedal press.
--
-- Most apps only have one command per foot. Some, like Mail, require two

local footpedalKeyCombos = {}
footpedalKeyCombos["Mail"]     = { {{"cmd","shift"}, "k", "k"}, {{}, "up", "down"} }
footpedalKeyCombos["Safari"]   = { {{"cmd","shift"}, "[", "]" } }
footpedalKeyCombos["Tweetbot"] = { {{"cmd"}, "[", "]" } }
footpedalKeyCombos["iTunes"]   = { {{"cmd"}, "left", "right" } }
footpedalKeyCombos["Photos"]   = { {{"cmd"}, "left", "right" } }
footpedalKeyCombos["Messages"] = { {{"cmd"}, "[", "]" } }
footpedalKeyCombos["Calendar"] = { {{"cmd"}, "left", "right" } }

-- Initialize footpedal bindings
function footpedals.init()
    -- F18 is left footpedal
    hs.hotkey.bind({""}, "f18", function()
        runFootpedalCommandsForFoot(footpedalKeyCombos[frontmostAppName()], "left")
    end)

    -- F19 is right footpedal
    hs.hotkey.bind({""}, "f19", function()
        runFootpedalCommandsForFoot(footpedalKeyCombos[frontmostAppName()], "right")
    end)
end

return footpedals
