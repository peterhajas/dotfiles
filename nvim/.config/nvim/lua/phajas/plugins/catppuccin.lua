require("catppuccin").setup({
    flavour = "mocha",
    integrations = {
        harpoon = true,
        treesitter_context = false,
    }
})

vim.cmd.colorscheme "catppuccin"
