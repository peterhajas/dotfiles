require "hyper"

hs.window.animationDuration = 0
hs.grid.GRIDWIDTH = 6
hs.grid.GRIDHEIGHT = 2

local margins = hs.geometry.size(4, 4)

hs.grid.setMargins(margins)
hs.grid.ui.showExtraKeys = false

hs.hotkey.bind(hyper, "space", function()
    hs.grid.toggleShow()
end)

