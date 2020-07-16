-- from https://stackoverflow.com/a/7615129
function mysplit (inputstr, sep)
if sep == nil then
    sep = "%s"
end
local t={}
for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
end
return t
end

local chosen = nil
local exited = false
function prepareChooser(args)
    chosen = nil
    exited = false
    local chooser = hs.chooser.new(function(picked)
        exited = true
        if not picked then return end
        chosen = picked["text"]
    end)

    local choices = {}
    local argsSplit = mysplit(args, "|")
    for k,v in pairs(argsSplit) do
        table.insert(choices, { text = v })
    end

    chooser:width(20)
    chooser:choices(choices)
    chooser:show()
end

function getChosen()
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

