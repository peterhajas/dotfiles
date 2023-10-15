local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
 })
end

vim.opt.rtp:prepend(lazypath)

local plugins = {
    {'tpope/vim-commentary'},
    {'numToStr/Comment.nvim'},
    {'tpope/vim-surround'},
    {'tpope/vim-unimpaired'},

    {'mbbill/undotree'},

    {'folke/zen-mode.nvim'},

    {'dhruvasagar/vim-table-mode'},

    {'nvim-telescope/telescope.nvim', tag = '0.1.3', dependencies = {'nvim-lua/plenary.nvim'}},

    {'stevearc/oil.nvim'},

    {'nvim-treesitter/nvim-treesitter', cmd = {'TSUpdate'}},
    {'nvim-treesitter/playground'},
    {'nvim-treesitter/nvim-treesitter-context'},

    -- LSP Support
    {'VonHeikemen/lsp-zero.nvim', branch = 'v3.x', dependencies = {

    }},
    {'neovim/nvim-lspconfig', dependencies = {
        'hrsh7th/cmp-nvim-lsp',
        'williamboman/mason.nvim',
        'williamboman/mason-lspconfig.nvim',
        'j-hui/fidget.nvim',
    }},
    -- Autocompletion
    {'hrsh7th/nvim-cmp', dependencies = {
        'L3MON4D3/LuaSnip',
        'hrsh7th/cmp-buffer',
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-nvim-lua',
        'hrsh7th/cmp-path',
        'rafamadriz/friendly-snippets',
        'saadparwaiz1/cmp_luasnip',
    }},
    -- Harpoon
    {'theprimeagen/harpoon'},
    -- Git
    {'tpope/vim-fugitive'},
    {'lewis6991/gitsigns.nvim'},
    -- {'braxtons12/blame_line.nvim'} - disabled
    -- Status Line
    {'nvim-lualine/lualine.nvim', dependencies = {
        'nvim-tree/nvim-web-devicons',
    }},
    { 'catppuccin/nvim', name = "catppuccin", priority = 1000 },
}

local opts = {}

-- Set up Lazy
require("lazy").setup(plugins, opts)

