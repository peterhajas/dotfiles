-- Dark Mode Module
-- Toggles macOS dark mode via Hyper-\

local darkmode = {}

local hyper = require "hyper"

-- Private helper functions

local function isInDarkMode()
    -- Read defaults
    local defaultsCommand = "defaults read -g AppleInterfaceStyle"
    local result = hs.execute(defaultsCommand)
    if string.find(result, 'Dark') then
        return true
    else
        return false
    end
end

local function toggleDarkMode()
    local applescript = [[
        tell application "System Events"
            tell appearance preferences
                set dark mode to not dark mode
            end tell
        end tell
    ]]
    hs.osascript.applescript(applescript)

    hs.console.darkMode(isInDarkMode())
end

-- Initialize dark mode module
function darkmode.init()
    -- Hyper-\ for toggling theme
    hs.hotkey.bind(hyper.key, "\\", function()
        toggleDarkMode()
    end)
end

return darkmode

