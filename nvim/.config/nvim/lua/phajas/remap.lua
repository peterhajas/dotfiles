vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- Splits
vim.keymap.set("n", "<leader>w", "<C-w>v<C-w>l")
vim.keymap.set("n", "<leader>W", "<C-w>s<C-w>j")

-- Window movement
vim.keymap.set("n", "<left>", "<C-w>h")
vim.keymap.set("n", "<right>", "<C-w>l")
vim.keymap.set("n", "<up>", "<C-w>k")
vim.keymap.set("n", "<down>", "<C-w>j")

-- Tabs
vim.keymap.set("n", "<leader>t", vim.cmd.tabnew)
-- plh-evil: why aren't these ]t and [t? some unimpaired.vim collision?
vim.keymap.set("n", "]w", vim.cmd.tabnext)
vim.keymap.set("n", "[w", vim.cmd.tabprevious)

-- Folds
vim.keymap.set("n", "<leader>f", "za")

-- Editing
vim.keymap.set("n", "S", "i<cr><esc><right>")
