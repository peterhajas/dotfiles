-- Most of these settings were extracted or modified from my .vimrc. I made some
-- effort to sort them
--
-- Set our clipboard to map to the system one
vim.opt.clipboard = "unnamed"

-- Turn off gui stuff
vim.opt.guicursor = ""
-- but leave on the mouse
vim.opt.mouse = "a"

-- Number and relative number
vim.opt.number = true
vim.opt.relativenumber = true

-- Soft tab lifestyle
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.smartindent = true
vim.opt.smarttab = true
vim.opt.softtabstop = 4
vim.opt.tabstop = 4

-- Turn on wrapping (I'm used to it)
vim.opt.wrap = true

-- Searching should be incremental but not highlight
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.showmatch = true
vim.opt.smartcase = true

-- Visuals
vim.opt.termguicolors = true

-- Colorcolumn
vim.opt.colorcolumn = "81"
vim.api.nvim_set_hl(0, "ColorColumn", { ctermbg="Black", bg="Black" })
vim.api.nvim_set_hl(0, "SignColumn", { ctermbg="NONE", bg="NONE" })

-- Signcolumn
vim.opt.signcolumn = "yes"

-- Undo, Swap, Backup
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

-- Diagnostics

-- Show in a floating window
vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
        vim.diagnostic.open_float(nil, { focus = false })
    end
})
-- ...and tear them down when the cursor moves
vim.api.nvim_create_autocmd({"CursorMoved", "WinLeave", "BufLeave"}, {
    callback = function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local config = vim.api.nvim_win_get_config(win)
            if config.relative ~= "" then
                -- Don't close if it's likely treesitter-context (high zindex)
                if not (config.zindex and config.zindex >= 20) then
                    pcall(vim.api.nvim_win_close, win, false)
                end
            end
        end
    end,
})

-- Cut the "update time" so that we can show the diagnostics faster
vim.opt.updatetime = 0

-- Misc.
vim.opt.scrolloff = 12
vim.opt.autoread = true
vim.opt.autowrite = true
vim.opt.visualbell = true

-- Window Resize Helpers
vim.api.nvim_create_autocmd({"WinResized"}, {
    group = vim.api.nvim_create_augroup("phajas-resize", { clear = true }),
    callback = function()
        vim.api.nvim_cmd(vim.api.nvim_parse_cmd("wincmd =", {}), {})
    end,
})

-- Disable LSP and syntax for large files
vim.api.nvim_create_autocmd({"BufReadPost"}, {
    callback = function()
        local line_count = vim.fn.line('$')
        local max_lines = 10000

        if line_count > max_lines then
            vim.notify("File has " .. line_count .. " lines. Disabling LSP and syntax for performance.", vim.log.levels.WARN)
            vim.cmd("syntax off")
            vim.cmd("TSBufDisable highlight")
            vim.b.large_file = true

            -- Disable LSP for this buffer
            vim.schedule(function()
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                for _, client in ipairs(clients) do
                    vim.lsp.buf_detach_client(0, client.id)
                end
            end)
        end
    end,
})
