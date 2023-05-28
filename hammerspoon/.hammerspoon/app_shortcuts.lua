require('hyper')
require('util')
-- App Shortcuts {{{
-- Option {{{

-- -- Option-M for Mail

-- hs.hotkey.bind({"alt"}, "m", function()
--     hs.application.launchOrFocus("Mail")
-- end)

-- -- Option-A for Messages

-- hs.hotkey.bind({"alt"}, "a", function()
--     hs.application.launchOrFocus("Messages")
-- end)

-- -- Option-Tab for Terminal

-- hs.hotkey.bind({"alt"}, "tab", function()
--     hs.application.launchOrFocus("Terminal")
-- end)

-- -- Option-R for Reeder
-- hs.hotkey.bind({"alt"}, "r", function()
--     hs.application.launchOrFocus("Reeder")
-- end)

-- -- Option-H for HomeAssistant
-- hs.hotkey.bind({"alt"}, "h", function()
--     hs.application.launchOrFocus("Home Assistant")
-- end)

-- }}}
-- Hyper {{{
local hyperAppShortcuts = {
    ['a'] = 'Messages',
    ['s'] = 'Safari',
    ['d'] = 'Finder',
    ['f'] = 'Terminal',
    ['g'] = 'Mail',
    ['c'] = 'Calendar',
    ['b'] = 'Home Assistant',
    ['r'] = 'Reeder',
}

for shortcut,appString in pairs(hyperAppShortcuts) do
    hs.hotkey.bind(hyper, shortcut, function()
        local app = hs.application.get(appString)
        if app == nil then
            hs.application.open(appString)
            return
        end
        if app:isRunning() then
            if app:isFrontmost() then
                app:hide()
            else
                hs.application.open(appString)
                app:activate()
            end
        else
            hs.application.open(app)
        end
    end)
end

-- }}}
-- }}}
