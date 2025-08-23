local builtin = require('telescope.builtin')

require('telescope').load_extension('fzf')

vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
vim.keymap.set('n', '<leader>pF', function() builtin.find_files({ hidden = true }) end)
vim.keymap.set('n', '<leader>pg', builtin.git_files, {})
vim.keymap.set('n', '<leader>ps', builtin.live_grep, {})

vim.keymap.set('n', '<leader>gB', builtin.git_branches, {})

vim.keymap.set('n', 'gd', function()
    builtin.lsp_definitions()
end)
