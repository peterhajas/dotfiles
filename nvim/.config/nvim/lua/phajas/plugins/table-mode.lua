vim.api.nvim_create_autocmd({"BufEnter"}, {
    group = vim.api.nvim_create_augroup("phajas-markdown-tables", { clear = true }),
    pattern = {"*.md"},
    callback = function()
        -- Switch to md corners
        vim.api.nvim_exec2("let g:table_mode_corner='|'", {})
        -- Enter table mode
        vim.api.nvim_exec2("TableModeEnable", {})
        -- Enter insert mode, then press escape
        -- This gets rid of the "Table mode enabled" debug message
        local keys = vim.api.nvim_replace_termcodes('i<ESC>',true,false,true)
        vim.api.nvim_feedkeys(keys,'m',false)
    end,
})
