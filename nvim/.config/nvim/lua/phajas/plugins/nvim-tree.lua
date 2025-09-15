local api = require("nvim-tree.api")

require("nvim-tree").setup {
    update_focused_file = {
        enable = true
    },
}

vim.keymap.set('n', '<leader>s', function()
    api.tree.toggle()
end)
