require "hyper"
require "util"

function toggleDarkMode()
    local applescript = [[
        tell application "System Events"
            tell appearance preferences
                set dark mode to not dark mode
            end tell
        end tell
    ]]
    hs.osascript.applescript(applescript)
end

function isInDarkMode()
    -- Read defaults
    local defaultsCommand = "defaults read -g AppleInterfaceStyle"
    local result = hs.execute(defaultsCommand)
    if string.find(result, 'Dark') then
        return true
    else
        return false
    end
end

-- Hyper-\ for toggling theme

hs.hotkey.bind(hyper, "\\", function()
    toggleDarkMode()
end)

