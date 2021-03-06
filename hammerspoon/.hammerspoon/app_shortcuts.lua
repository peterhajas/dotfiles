-- App Shortcuts {{{

-- Option-M for Mail

hs.hotkey.bind({"alt"}, "m", function()
    hs.application.launchOrFocus("Mail")
end)

-- Option-A for Messages

hs.hotkey.bind({"alt"}, "a", function()
    hs.application.launchOrFocus("Messages")
end)

-- Option-Tab for Terminal

hs.hotkey.bind({"alt"}, "tab", function()
    hs.application.launchOrFocus("Terminal")
end)

-- Option-R for Reeder
hs.hotkey.bind({"alt"}, "r", function()
    hs.application.launchOrFocus("Reeder")
end)

-- Option-T for Textual

hs.hotkey.bind({"alt"}, "t", function()
    hs.application.launchOrFocus("Textual 5")
end)

-- Option-H for HomeAssistant
hs.hotkey.bind({"alt"}, "h", function()
    hs.application.launchOrFocus("Home Assistant")
end)

-- }}}
