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
vim.keymap.set("n", "<Space>", "za")
vim.keymap.set("n", "<leader>F", function() vim.opt.foldenable = not vim.opt.foldenable end)

-- Finding
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Editing
-- Split lines
vim.keymap.set("n", "S", "i<cr><esc><right>")
-- Backspace to % for matching bracket
vim.keymap.set("n", "<BS>", "%")
-- Move selected text around (thanks theprimeagen)
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
