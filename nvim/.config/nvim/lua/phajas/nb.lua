local builtin = require('telescope.builtin')

local function NB()
    local notebook = vim.fn.systemlist("nb notebook --path")[1]
    builtin.live_grep{
        cwd = notebook,
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
