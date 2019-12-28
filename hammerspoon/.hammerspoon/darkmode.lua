require "hyper"

function toggleDarkMode ()
    local applescript = [[
        tell application "System Events"
            tell appearance preferences
                set dark mode to not dark mode
            end tell
        end tell
    ]]
    hs.osascript.applescript(applescript)
end

-- Hyper-\ for toggling theme

hs.hotkey.bind(hyper, "\\", function()
    toggleDarkMode()
end)
