-- Nyx-specific Neovim configuration
-- Game Boy inspired minimal setup
-- To use: add `require('nyx')` to your init.lua on Nyx

vim.opt.termguicolors = true

-- Clipboard
vim.opt.clipboard = "unnamed"

-- Turn off gui stuff
vim.opt.guicursor = ""
-- but leave on the mouse
vim.opt.mouse = "a"

-- Number and relative number
vim.opt.number = true
vim.opt.relativenumber = true

-- Soft tab lifestyle
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.smartindent = true
vim.opt.smarttab = true
vim.opt.softtabstop = 4
vim.opt.tabstop = 4

-- Turn on wrapping
vim.opt.wrap = true

-- Searching should be incremental but not highlight
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.showmatch = true
vim.opt.smartcase = true

-- Visuals
vim.opt.termguicolors = true

-- Colorcolumn
vim.opt.colorcolumn = "81"
vim.api.nvim_set_hl(0, "ColorColumn", { ctermbg="Black", bg="Black" })
vim.api.nvim_set_hl(0, "SignColumn", { ctermbg="NONE", bg="NONE" })

-- Signcolumn
vim.opt.signcolumn = "auto:1"

-- Undo, Swap, Backup
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

-- Misc.
vim.opt.scrolloff = 12
vim.opt.autoread = true
vim.opt.autowrite = true
vim.opt.visualbell = true

-- Window Resize Helpers
vim.api.nvim_create_autocmd({"WinResized"}, {
    group = vim.api.nvim_create_augroup("phajas-resize", { clear = true }),
    callback = function()
        vim.api.nvim_cmd(vim.api.nvim_parse_cmd("wincmd =", {}), {})
    end,
})
