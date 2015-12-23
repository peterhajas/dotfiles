-- Preferred screen {{{

function preferredScreen ()
    return hs.screen.allScreens()[1]
end

function preferredScreenFrame ()
    local frame = preferredScreen():frame()
    return frame
end

-- }}}
