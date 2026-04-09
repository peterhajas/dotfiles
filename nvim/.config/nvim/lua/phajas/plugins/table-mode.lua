vim.api.nvim_create_autocmd({"FileType"}, {
    group = vim.api.nvim_create_augroup("phajas-markdown-tables", { clear = true }),
    pattern = {"markdown"},
    callback = function(ev)
        local buftype = vim.api.nvim_buf_get_option(ev.buf, "buftype")
        local bufname = vim.api.nvim_buf_get_name(ev.buf)

        -- Skip non-normal buffers, except tw:// acwrite buffers
        if buftype ~= "" then
            if not (buftype == "acwrite" and bufname:match("^tw://")) then
                return
            end
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

vim.api.nvim_create_autocmd({"BufWritePost"}, {
    group = vim.api.nvim_create_augroup("phajas-markdown-tables-realign", { clear = true }),
    pattern = {"*"},
    callback = function(ev)
        local buftype = vim.bo[ev.buf].buftype
        local bufname = vim.api.nvim_buf_get_name(ev.buf)

        if vim.bo[ev.buf].filetype ~= "markdown" then
            return
        end

        -- Skip non-normal buffers, except tw:// acwrite buffers
        if buftype ~= "" then
            if not (buftype == "acwrite" and bufname:match("^tw://")) then
                return
            end
        end

        if vim.b[ev.buf].table_mode_active == 1 then
            vim.cmd("TableModeRealign")
        end
    end,
})
