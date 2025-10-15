local api = require("nvim-tree.api")

require("nvim-tree").setup {
    renderer = {
        icons = {
            show = {
                file = true,
                folder = true,
                folder_arrow = true,
                git = true,
            },
        },
        indent_width = 1,
    },
    update_focused_file = {
        enable = true
    },
    on_attach = function(bufnr)
        local function open_or_toggle()
            local node = api.tree.get_node_under_cursor()
            if node then
                if node.type == 'file' then
                    api.node.open.edit()
                elseif node.type == 'directory' then
                    api.node.open.edit()
                end
            end
        end

        -- Enter key to open files and toggle folders
        vim.keymap.set('n', '<CR>', open_or_toggle, { buffer = bufnr, desc = "Open file or toggle folder" })
    end,
}

vim.keymap.set('n', '<leader>s', function()
    api.tree.toggle()
end)
