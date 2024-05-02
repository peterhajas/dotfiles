require "hyper"

hs.hotkey.bind(hyper, ";", function()
    hs.grid.ui.showExtraKeys = false
    local margins = hs.geometry.point(0, 0)
    hs.grid.setMargins(margins).setGrid(hs.geometry.size(10, 4)).toggleShow()
end)

