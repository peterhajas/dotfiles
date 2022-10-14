require "hyper"
require "choose"
require "util"

hs.hotkey.bind(hyper, "q", function()
    -- Grab all the passwords
    local allPasswords = hs.execute('pass_all')
    allPasswords = split(allPasswords, '\n')

    -- Pipe them into choose
    showChooser(allPasswords, function(picked)
        if picked == nil then return end
        local output = hs.execute('pass -c ' .. picked)
        hs.alert(output)
    end)
end)
