-- Chooser Module
-- Provides a UI chooser for selecting from a list of options

local chooser = {}

require 'util'

-- Private state for CLI chooser
local chosen = nil
local exited = false

-- Show a chooser with the given choices, calling completion with the chosen item
function chooser.show(choices, completion)
    local hs_chooser = hs.chooser.new(function(picked)
        local pickedContents = nil
        if picked ~= nil then
            local text = picked['text']:getString()
            pickedContents = text
        end
        completion(pickedContents)
    end)

    local primaryTextColor = hs.drawing.color.lists()['System']['labelColor']

    -- We need to format the choices for hs.chooser
    local chooserChoices = { }
    for k,v in pairs(choices) do
        local styledText = hs.styledtext.new(v, {
            font = { name = "Menlo", size = 18 },
            color = primaryTextColor
        })
        table.insert(chooserChoices, { text = styledText })
    end

    hs_chooser:width(20)
    hs_chooser:choices(chooserChoices)
    hs_chooser:show()
end

-- Show chooser from CLI with pipe-separated arguments
function chooser.showCLI(args)
    chosen = nil
    exited = false

    local choices = {}
    local argsSplit = split(args, "|")
    for k,v in pairs(argsSplit) do
        table.insert(choices, v)
    end

    chooser.show(choices, function(picked)
        exited = true
        if not picked then return end
        chosen = picked
    end)
end

-- Get the chosen value from CLI chooser
function chooser.getCLIChosen()
    local out = nil
    if exited then
        if chosen then
            out = chosen
        else
            out = "NOTHING_PICKED_IN_CHOOSER"
        end
        -- Only reset after we've returned a non-nil value
        chosen = nil
        exited = false
    end

    return out
end

-- Export as globals for CLI compatibility
showChooserCLI = chooser.showCLI
getCLIChosen = chooser.getCLIChosen
showChooser = chooser.show

return chooser

