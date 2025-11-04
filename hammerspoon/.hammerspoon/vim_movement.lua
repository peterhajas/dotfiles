-- Vim Movement Shortcuts Module
-- Maps Ctrl+hjkl to arrow keys for vim-style navigation

local vim_movement = {}

-- Private state
local binds = {}

-- Initialize vim movement shortcuts
function vim_movement.init()
    table.insert(binds, hs.hotkey.bind({"ctrl"}, "h",
                        function() local key = hs.eventtap.event.newKeyEvent({}, "left", true) key:post() end))
    table.insert(binds, hs.hotkey.bind({"ctrl"}, "j",
                        function() local key = hs.eventtap.event.newKeyEvent({}, "down", true) key:post() end))
    table.insert(binds, hs.hotkey.bind({"ctrl"}, "k",
                        function() local key = hs.eventtap.event.newKeyEvent({}, "up", true) key:post() end))
    table.insert(binds, hs.hotkey.bind({"ctrl"}, "l",
                        function() local key = hs.eventtap.event.newKeyEvent({}, "right", true) key:post() end))
end

return vim_movement
