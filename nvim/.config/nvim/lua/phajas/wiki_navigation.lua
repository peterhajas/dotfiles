History = require("phajas.wiki_history")
Paths = require("phajas.wiki_paths")

local N = {}

function N.NavigateToFile(winno, frombufno, title)
    local path = Paths.FilePath(title)
    local fromPath = vim.api.nvim_buf_get_name(frombufno)

    if path == nil then
        local directory = vim.fn.fnamemodify(fromPath, ":h")
        local newPath = directory .. "/" .. title .. ".md"
        local file = io.open(newPath, 'w')
        if file then
            path = newPath
            file:close()
        else
            print('Failed to create the file:', newPath)
            return
        end
    end

    -- Log this in History
    History.PushHistory(winno, fromPath)

    -- Focus the window
    vim.api.nvim_win_call(winno, function()
        -- Edit the file
        vim.api.nvim_command("edit " .. path)
    end)
end

function N.GoBack(winno)
    local path = History.PopHistory(winno)
    if path ~= nil then
        vim.api.nvim_command("edit " .. path)
    end
end

function N.OpenFileAtCursor(winno, intoWinno, bufno)
    local row, column = unpack(vim.api.nvim_win_get_cursor(winno))
    local line = vim.api.nvim_buf_get_lines(bufno, row-1, row, false)[1]
    local startIndex = nil
    local endIndex = nil
    local title = nil
    startIndex, endIndex = 1, 1

    -- Find where square brackets are, if anywhere
    while startIndex and endIndex do
        startIndex, endIndex = string.find(line, "%[%[", endIndex)
        if startIndex and endIndex then
            local startBrackets, endBrackets = string.find(line, "%]%]", endIndex)
            if startBrackets and endBrackets then
                title = string.sub(line, startIndex, endBrackets)
                endIndex = endBrackets + 1
                break
            end
        end
    end

    if startIndex ~= nil and endIndex ~= nil and
        startIndex < column+2 and endIndex > column-2 and
        title ~= nil then
        title = string.gsub(title, "%[", "")
        title = string.gsub(title, "%]", "")
        Navigation.NavigateToFile(intoWinno, bufno, title)
    else
        -- If there's just a filename on this line, then go with that
        local lineFilePath = Paths.FilePath(line)
        if lineFilePath ~= nil then
            Navigation.NavigateToFile(intoWinno, bufno, line)
        else
            print("Not yet implemented") -- plh-evil: fix me, find selected text
        end
    end
end

return N
