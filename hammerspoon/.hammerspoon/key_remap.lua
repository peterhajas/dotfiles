-- Vim Movement Shortcuts

hs.hotkey.bind({"ctrl"}, "h", function()
    local key = hs.eventtap.event.newKeyEvent({}, "left", true)
    key:post()
end)

hs.hotkey.bind({"ctrl"}, "j", function()
    local key = hs.eventtap.event.newKeyEvent({}, "down", true)
    key:post()
end)

hs.hotkey.bind({"ctrl"}, "k", function()
    local key = hs.eventtap.event.newKeyEvent({}, "up", true)
    key:post()
end)

hs.hotkey.bind({"ctrl"}, "l", function()
    local key = hs.eventtap.event.newKeyEvent({}, "right", true)
    key:post()
end)

-- Other Shortcuts

-- Hyper-escape to toggle the Hammerspoon console

hs.hotkey.bind(hyper, "escape", function()
    hs.toggleConsole()
end)

-- Shift-escape to ~

hs.hotkey.bind({"shift"}, "escape", function()
    hs.eventtap.keyStroke({"shift"}, "`")
end)

-- Command-escape to cmd-`

hs.hotkey.bind({"cmd"}, "escape", function()
    hs.eventtap.keyStroke({"cmd"}, "`")
end)

