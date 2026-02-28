-- Configure vim-dadbod-ui settings
vim.g.db_ui_auto_execute_table_helpers = 1
vim.g.db_ui_table_helpers = {
    sqlite = {
        List = "SELECT * FROM '{table}'"
    }
}

local db_patterns = { "*.db", "*.sqlite", "*.sqlite3", "*.duckdb", "*.ddb" }

local function maybe_open_db_ui(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then
        return
    end

    local ext = name:match("%.([^.]+)$") or ""
    local is_db = ext == "db" or ext == "sqlite" or ext == "sqlite3" or ext == "duckdb" or ext == "ddb"
    if not is_db then
        return
    end

    vim.schedule(function()
        local filepath = vim.fn.fnamemodify(name, ":p")
        local filename = vim.fn.fnamemodify(name, ":t:r")

        -- Close the binary file buffer first
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.cmd("bdelete")
        end

        -- Determine database type from file extension
        local db_type = "sqlite" -- default
        if ext == "duckdb" or ext == "ddb" then
            db_type = "duckdb"
        end

        -- Set up the database connection using VimScript
        vim.cmd(string.format([[
            if !exists('g:dbs')
                let g:dbs = {}
            endif
            let g:dbs['%s'] = '%s:%s'
        ]], filename, db_type, filepath))

        -- Open DBUI with the connection available
        vim.cmd("DBUI")
    end)
end

-- Auto-open DBUI and create connection when opening database files
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = db_patterns,
    callback = function(args)
        maybe_open_db_ui(args.buf)
    end,
})

-- Handle the current buffer on startup if needed
maybe_open_db_ui(0)
