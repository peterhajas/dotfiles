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
        vim.cmd("wincmd w")
    end)

    -- Edit the file
    vim.api.nvim_command("edit " .. path)
end

function N.GoBack(winno)
    local path = History.PopHistory(winno)
    if path ~= nil then
        vim.api.nvim_command("edit " .. path)
    end
end

return N
