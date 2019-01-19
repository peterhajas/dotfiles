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

    -- If Safari is frontmost, hide and then show it
    -- This is to trigger the Dark Mode for Safari plugin to reload its CSS for
    -- the current page
    local frontmostApp = hs.application.frontmostApplication()
    if frontmostApp:name() == "Safari" then
        frontmostApp:hide()
        hs.timer.doAfter(0.1, function()
            frontmostApp:unhide()
            frontmostApp:activate()
        end)
    end
end

-- Hyper-\ for toggling theme

hs.hotkey.bind(hyper, "\\", function()
    toggleDarkMode()
end)
