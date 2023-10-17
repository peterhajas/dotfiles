local H = { }

H._History = { }

function H._GetHistory(winno)
    if H._History[winno] == nil then
        H._History[winno] = { }
    end
    return H._History[winno]
end

function H._SetHistory(winno, history)
    H._History[winno] = history
end

function H.PushHistory(winno, path)
    local history = H._GetHistory(winno)
    history = table.insert(history, path)
    return history
end

-- Pops the history for the window number
-- Returns the path to go to in history
function H.PopHistory(winno)
    local history = H._GetHistory(winno)
    local popped = table.remove(history)
    return popped
end

return H
