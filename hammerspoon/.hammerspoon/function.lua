require "hyper"

-- Hyper 5 to do f3
hs.hotkey.bind(hyper, "5", function()
    hs.eventtap.keyStroke({"fn"}, "f3")
end)
