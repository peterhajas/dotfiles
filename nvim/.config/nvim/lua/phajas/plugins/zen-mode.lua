require("zen-mode").setup {
    plugins = {
        options = {
            laststatus = 3
        }
    }
}

vim.keymap.set("n", "<leader>;", function()
    require("zen-mode").toggle()
end, { desc = "Zen mode toggle" })
