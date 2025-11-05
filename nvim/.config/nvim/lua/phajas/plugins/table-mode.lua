vim.api.nvim_create_autocmd({"FileType"}, {
    group = vim.api.nvim_create_augroup("phajas-markdown-tables", { clear = true }),
    pattern = {"markdown"},
    callback = function(ev)
        -- Don't enable table mode in special buffers (telescope previews, etc)
        local buftype = vim.api.nvim_buf_get_option(ev.buf, "buftype")
        local bufname = vim.api.nvim_buf_get_name(ev.buf)

        -- Skip non-normal buffers (nofile, prompt, etc) and tw:// buffers
        if buftype ~= "" or bufname:match("^tw://") then
            return
        end

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
