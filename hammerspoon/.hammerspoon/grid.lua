require "hyper"

hs.window.animationDuration = 0

-- Found by taking the largest res I run at (3200) and diving by hint keys on
-- the keyboard
local screenWidthPerGridUnit = 3200 / 10
-- Likewise with height (1800 is the largest)
local screenHeightPerGridUnit = 1800 / 4

function updateGridForScreen(screen)
    local w = screen:fullFrame().w
    local h = screen:fullFrame().h

    w = w / screenWidthPerGridUnit
    h = h / screenHeightPerGridUnit

    w = math.floor(w)
    h = math.floor(h)

    w = math.max(w, 3)
    h = math.max(h, 3)

    size = hs.geometry.size(w, h)

    hs.grid.setGrid(size, screen)
end

function updateGridsForScreens()
    screens = hs.screen.allScreens()
    for i, screen in ipairs(screens) do
        updateGridForScreen(screen)
    end
end

updateGridsForScreens()

local margins = hs.geometry.size(4, 4)

hs.grid.setMargins(margins)
hs.grid.ui.showExtraKeys = false

hs.hotkey.bind(hyper, "space", function()
    hs.grid.toggleShow()
end)

