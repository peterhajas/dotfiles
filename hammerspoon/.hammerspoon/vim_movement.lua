-- Vim Movement Shortcuts {{{

local binds = {}

local function setUpVimMovementShortcuts()
    table.insert(binds, hs.hotkey.bind({"ctrl"}, "h",
                        function() local key = hs.eventtap.event.newKeyEvent({}, "left", true) key:post() end))
    table.insert(binds, hs.hotkey.bind({"ctrl"}, "j",
                        function() local key = hs.eventtap.event.newKeyEvent({}, "down", true) key:post() end))
    table.insert(binds, hs.hotkey.bind({"ctrl"}, "k",
                        function() local key = hs.eventtap.event.newKeyEvent({}, "up", true) key:post() end))
    table.insert(binds, hs.hotkey.bind({"ctrl"}, "l",
                        function() local key = hs.eventtap.event.newKeyEvent({}, "right", true) key:post() end))
end

setUpVimMovementShortcuts()

-- }}}
