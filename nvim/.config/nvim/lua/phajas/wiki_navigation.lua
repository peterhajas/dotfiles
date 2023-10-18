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
        -- Keep track of what text we will need to replace with the
        -- Wiki-fied link in the buffer
        local startRow = row
        local endRow = row
        local startCol = column
        local endCol = column

        local visualMode = vim.fn.mode() == 'v' or vim.fn.mode() == 'V'
        local wikiLink = line

        -- If there's just a filename on this line, then go with that
        -- plh-evil - once we have word-level linkification, this should
        -- create the file if it's not there (and remove the if-conditional)
        local lineFilePath = Paths.FilePath(line)
        if lineFilePath ~= nil then
            startRow = row - 1
            endRow = row - 1
            startCol = 0
            endCol = string.len(line)
            wikiLink = line
            -- Navigation.NavigateToFile(intoWinno, bufno, line)
        elseif visualMode then
            local startPos = vim.fn.getpos("'<")
            local endPos = vim.fn.getpos("'>")
            startRow = startPos[2] - 1
            startCol = startPos[3]
            endRow = endPos[2] - 1
            endCol = endPos[3]
        else
            print("not yet implemented")
            return
        end

        wikiLink = vim.api.nvim_buf_get_text(bufno, startRow, startCol, endRow, endCol, {})[1]

        -- plh-evil: this does not work in visual mode
        wikiLink = "[[" .. wikiLink .. "]]"
        P({startRow, startCol, endRow, endCol, wikiLink})
        vim.api.nvim_buf_set_text(bufno, startRow, startCol, endRow, endCol, {wikiLink})
    end
end

return N
