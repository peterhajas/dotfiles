local builtin = require('telescope.builtin')

local function NBNotebookPath()
    return vim.fn.systemlist("nb notebook --path")[1]
end

local function NB()
    builtin.live_grep{
        cwd = NBNotebookPath(),
        prompt_title = "nb search (start typing)"
    }
end

local function NBJournal()
    local name = vim.fn.systemlist("nb_journal_title")[1]
    local path = vim.fn.system("nb_create_if_needed " .. name)
    vim.cmd('edit ' .. path)
end

vim.api.nvim_create_user_command('NB', NB, {})

vim.api.nvim_create_user_command('NBJournal', NBJournal, {})

vim.keymap.set('n', '<leader>n', function() NB() end, {})
vim.keymap.set('n', '<leader>j', function() NBJournal() end, {})

vim.api.nvim_create_autocmd({"BufWritePost"}, {
    group = vim.api.nvim_create_augroup("phajas-nb", { clear = true }),
    pattern = NBNotebookPath() .. "/*",
    callback = function(opts)
        -- We checkpoint here in case the backlinks operation borks something
        vim.fn.system("nb git checkpoint")
        vim.fn.system("nb_backlinks_prune.py")
        vim.fn.system("nb backlink --force")
        vim.fn.system("nb git checkpoint")
        vim.fn.system("nb sync 2>>/dev/null")
    end,
})

