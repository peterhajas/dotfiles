-- Most of these settings were extracted or modified from my .vimrc. I made some
-- effort to sort them
--
-- Set our clipboard to map to the system one
vim.opt.clipboard = "unnamed"

-- Turn off gui stuff
vim.opt.guicursor = ""
vim.opt.guioptions = ""
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

-- Turn on wrapping (I'm used to it)
vim.opt.wrap = true

-- Searching should be incremental but not highlight
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.showmatch = true
vim.opt.smartcase = true

-- Colorcolumn
vim.opt.colorcolumn = "81"
vim.cmd 'highlight ColorColumn ctermbg=black guibg=black'

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
vim.opt.signcolumn = "auto:1"

