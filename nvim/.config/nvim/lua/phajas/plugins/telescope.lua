local builtin = require('telescope.builtin')

require('telescope').load_extension('fzf')

vim.keymap.set('n', '<leader>pf', function()
    builtin.find_files({
        hidden = true,
        no_ignore = false,  -- This makes it respect .gitignore
        find_command = { "fd", "--type", "f", "--hidden", "--exclude", ".git" }
    })
end)
vim.keymap.set('n', '<leader>pg', builtin.git_files, {})
vim.keymap.set('n', '<leader>ps', function()
    builtin.live_grep({
        additional_args = function(args)
            return vim.list_extend(args, {"--hidden", "--glob", "!.git"})
        end
    })
end)
vim.keymap.set('n', '<leader>pS', function()
    builtin.grep_string({ shorten_path = true, word_match = "-w", only_sort_text = true, search = "" })
end)

vim.keymap.set('n', '<leader>gB', builtin.git_branches, {})

vim.keymap.set('n', 'gd', function()
    builtin.lsp_definitions()
end)
