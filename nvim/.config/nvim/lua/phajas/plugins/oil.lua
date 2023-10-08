require("oil").setup {
    columns = {},
    keymaps = {
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["<leader-w>"] = "actions.select_vsplit",
        ["<leader-W>"] = "actions.select_split",
        ["<leader-t>"] = "actions.select_tab",
        ["<C-p>"] = "actions.preview",
        ["<C-c>"] = "actions.close",
        ["<C-l>"] = "actions.refresh",
        ["-"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["`"] = "actions.cd",
        ["~"] = "actions.tcd",
        ["gs"] = "actions.change_sort",
        ["gx"] = "actions.open_external",
        ["g."] = "actions.toggle_hidden",
    },
    view_options = {
        show_hidden = true,
    },
}

vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })

vim.api.nvim_create_user_command("Beacon", function()
    vim.api.nvim_command(":edit oil-ssh://beacon/")
    -- oil-ssh://beacon/
end, {})

