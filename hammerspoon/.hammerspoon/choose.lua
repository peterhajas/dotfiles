require 'util' 

-- Prepares the chooser for some options, calling `completion` with the chosen
-- item
function showChooser(choices, completion)
    local chooser = hs.chooser.new(function(picked)
        local pickedContents = nil
        if picked ~= nil then
            pickedContents = picked['text']
        end
        completion(pickedContents)
    end)

    -- We need to format the choices for hs.chooser
    local chooserChoices = { }
    for k,v in pairs(choices) do
        table.insert(chooserChoices, { text = v })
    end

    chooser:width(20)
    chooser:choices(chooserChoices)
    chooser:show()
end

local chosen = nil
local exited = false

function showChooserCLI(args)
    chosen = nil
    exited = false

    local choices = {}
    local argsSplit = split(args, "|")
    for k,v in pairs(argsSplit) do
        table.insert(choices, v)
    end

    showChooser(choices, function(picked)
        exited = true
        if not picked then return end
        chosen = picked
    end)
end

function getCLIChosen()
    local out = nil
    if exited then
        if chosen then
            out = chosen
        else
            out = "NOTHING_PICKED_IN_CHOOSER"
        end
    end
    chosen = nil
    exited = false

    return out
end

