Navigation = require("phajas.wiki_navigation")
History = require("phajas.wiki_history")
Info = require("phajas.wiki_info")
Paths = require("phajas.wiki_paths")

local function WikiBufferEnter(info)
    local bufno = info.buf

    vim.api.nvim_buf_set_keymap(bufno, 'n', '<CR>', '', {
        callback = function()
            local winno = vim.api.nvim_get_current_win()
            Navigation.OpenFileAtCursor(winno, winno, bufno)
        end
    })
    vim.api.nvim_buf_set_keymap(bufno, 'v', '<CR>', '', {
        callback = function()
            local winno = vim.api.nvim_get_current_win()
            Navigation.OpenFileAtCursor(winno, winno, bufno)
        end
    })
    vim.api.nvim_buf_set_keymap(bufno, 'n', '<BS>', '', {
        callback = function()
            local winno = vim.api.nvim_get_current_win()
            Navigation.GoBack(winno)
        end
    })
    vim.api.nvim_buf_set_keymap(bufno, 'n', '^', '', {
        callback = function()
            local winno = vim.api.nvim_get_current_win()
            Info.ToggleInfo(bufno, winno)
        end
    })
end

vim.api.nvim_create_autocmd({"BufEnter"}, {
    group = vim.api.nvim_create_augroup("phajas-wiki", { clear = true }),
    pattern = Paths.WikiFilePattern(),
    callback = function(info)
        local extension = string.match(info.file, "%.([^%.]+)$")
        if extension and string.lower(extension) == "md" then
            WikiBufferEnter(info)
            Info.UpdateInfoBuffer(info.buf, vim.api.nvim_get_current_win())
        end
    end,
})

