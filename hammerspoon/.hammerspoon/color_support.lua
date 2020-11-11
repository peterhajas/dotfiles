-- Returns a color mapping the floating point value from `fraction` to a
-- representative color. `fraction` is assumed to be in the range 0 to 1 (inc.)
function severityColorForFraction(fraction)
    if fraction <= 0.4 then
        return hs.drawing.color.lists()['hammerspoon']['osx_green']
    end
    if fraction <= 0.85 then
        return hs.drawing.color.lists()['hammerspoon']['osx_yellow']
    end
    return hs.drawing.color.lists()['hammerspoon']['osx_red']
end
