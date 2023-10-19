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

vim.api.nvim_create_autocmd({"BufEnter"}, {
    group = vim.api.nvim_create_augroup("phajas-nb-enter", { clear = true }),
    pattern = NBNotebookPath() .. "/*",
    callback = function(evt)
        vim.wo.linebreak = true
        require("gitsigns").detach(evt.buf)
    end,
})

vim.api.nvim_create_autocmd({"BufWritePost"}, {
    group = vim.api.nvim_create_augroup("phajas-nb-write", { clear = true }),
    pattern = NBNotebookPath() .. "/*",
    callback = function()
        vim.fn.system("nb git checkpoint")
    end,
})

