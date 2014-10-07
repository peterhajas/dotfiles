local application = require "mjolnir.application"
local hotkey = require "mjolnir.hotkey"
local window = require "mjolnir.window"
local fnutils = require "mjolnir.fnutils"

-- This is the hyper modifier that I've set up in Karabiner

local hyper = {"alt", "ctrl", "shift"}

-- When I use my computer, I group apps into categories

local primaryApps = {
                     "Safari",
                     "App Store",
                     "Mail"
                    }

local secondaryApps = {
                       "Messages",
                      }

-- Make it easy to reload the Mjolinr config

hotkey.bind(hyper, "R", function()
    mjolnir.reload()
end)

-- Just a test keybinding (from mjolnir.io) for playing around

hotkey.bind(hyper, "D", function()
    local apps = application.runningapplications()
    local appCount = #apps
    for i = 1,appCount do
        local app = apps[i]
        local appName = app:title()
        if fnutils.contains(primaryApps, appName) then
            print(appName)
            local appwindows = app:visiblewindows()
            local win = appwindows[1]
            local f = win:frame()
            f.x = f.x + 10
            win:setframe(f)
        end
    end
end)
