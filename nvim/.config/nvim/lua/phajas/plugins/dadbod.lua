-- Configure vim-dadbod-ui settings
vim.g.db_ui_auto_execute_table_helpers = 1
vim.g.db_ui_table_helpers = {
    sqlite = {
        List = "SELECT * FROM '{table}'"
    }
}

-- Auto-open DBUI and create connection when opening database files
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
    pattern = {"*.db", "*.sqlite", "*.sqlite3", "*.duckdb", "*.ddb"},
    callback = function()
        vim.schedule(function()
            local filepath = vim.fn.expand("%:p")
            local filename = vim.fn.expand("%:t:r")

            -- Close the binary file buffer first
            vim.cmd("bdelete")

            -- Determine database type from file extension
            local ext = vim.fn.expand("%:e")
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
    end,
})