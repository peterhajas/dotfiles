require "hyper"
hs.hotkey.bind(hyper, "p", function()
    -- This is kind of broken right now because it deadlocks
    hs.execute('pass_choose', true)
end)
