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
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-l>", "<C-w>l")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-j>", "<C-w>j")

-- Tabs
vim.keymap.set("n", "<leader>t", vim.cmd.tabnew)
-- plh-evil: why aren't these ]t and [t? some unimpaired.vim collision?
vim.keymap.set("n", "]w", vim.cmd.tabnext)
vim.keymap.set("n", "[w", vim.cmd.tabprevious)
vim.keymap.set("t", "]w", vim.cmd.tabnext)
vim.keymap.set("t", "[w", vim.cmd.tabprevious)

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

-- Terminal
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")

-- Opens a new terminal in a split
-- plh-evil: it'd be cool if each tab had one of these, and this function was
-- smart enough to "jump" there if we hit it again...
local function terminal()
    vim.cmd(vim.api.nvim_replace_termcodes("normal <C-w>s<C-w>j", true, true, true))
    vim.cmd(":terminal")
    vim.cmd(vim.api.nvim_replace_termcodes("normal A", true, true, true))
end

vim.keymap.set("n", "<leader><CR>", function() terminal() end)
vim.keymap.set("t", "<leader><CR>", function() terminal() end)
