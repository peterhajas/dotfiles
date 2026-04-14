-- Controller Module
-- Maps 8BitDo controller button presses to named actions
-- The controller presents as a keyboard sending shift+ctrl+alt + F-key combos

local controller = {}

-- Button name -> F-key mapping
local buttons = {
    L2    = "f1",
    L1    = "f2",
    Minus = "f3",
    Up    = "f4",
    Left  = "f5",
    Right = "f6",
    Down  = "f18",
    Star  = "f19",
    R2    = "f8",
    R1    = "f9",
    Plus  = "f10",
    X     = "f11",
    A     = "f12",
    Y     = "f13",
    B     = "f16",
    Heart = "f17",
}

local mods = {"shift", "ctrl", "alt"}

-- Action handlers per button
-- Each entry is a function, or nil to do nothing
local actions = {
    Up    = function() hs.eventtap.keyStroke({}, "up")    end,
    Down  = function() hs.eventtap.keyStroke({}, "down")  end,
    Left  = function() hs.eventtap.keyStroke({}, "left")  end,
    Right = function() hs.eventtap.keyStroke({}, "right") end,
    A     = function() hs.eventtap.keyStroke({}, "return") end,
    B     = function() hs.eventtap.keyStroke({}, "escape") end,
    L1    = function() hs.eventtap.keyStroke({"ctrl"}, "p")
                       hs.eventtap.keyStroke({}, "h")
                       hs.eventtap.keyStroke({}, "return") end,
    R1    = function() hs.eventtap.keyStroke({"ctrl"}, "p")
                       hs.eventtap.keyStroke({}, "l")
                       hs.eventtap.keyStroke({}, "return") end,
    L2    = function() hs.eventtap.keyStroke({"ctrl"}, "t")
                       hs.eventtap.keyStroke({}, "h")
                       hs.eventtap.keyStroke({}, "return") end,
    R2    = function() hs.eventtap.keyStroke({"ctrl"}, "t")
                       hs.eventtap.keyStroke({}, "l")
                       hs.eventtap.keyStroke({}, "return") end,
    Heart = function() hs.eventtap.keyStroke({"ctrl"}, ";") end,
    X     = function() hs.eventtap.keyStroke({"cmd", "shift"}, "t") end,
}

function controller.init()
    for name, key in pairs(buttons) do
        hs.hotkey.bind(mods, key, function()
            dbg("controller: " .. name)
            local action = actions[name]
            if action then action() end
        end)
    end
end

return controller
