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
    {'tpope/vim-fugitive'},
    {'tpope/vim-commentary'},
    {'tpope/vim-surround'},
    {'tpope/vim-unimpaired'},
    {'nvim-telescope/telescope.nvim', tag = '0.1.3', dependencies = {'nvim-lua/plenary.nvim'}},
    {'nvim-treesitter/nvim-treesitter', cmd = {'TSUpdate'}},
    {'nvim-treesitter/playground'},
    {'VonHeikemen/lsp-zero.nvim', branch = 'v3.x', dependencies = {

    }},
    -- LSP Support
    {'neovim/nvim-lspconfig', dependencies = {
        'hrsh7th/cmp-nvim-lsp',
        'williamboman/mason.nvim',
        'williamboman/mason-lspconfig.nvim',
        'j-hui/fidget.nvim',
    }},
    -- Autocompletion
    {'hrsh7th/nvim-cmp', dependencies = {
        'L3MON4D3/LuaSnip',
        'saadparwaiz1/cmp_luasnip',
        'hrsh7th/cmp-nvim-lsp',
        'rafamadriz/friendly-snippets',
    }},
    -- Harpoon
    {'theprimeagen/harpoon'}
}

local opts = {}

-- Set up Lazy
require("lazy").setup(plugins, opts)

-- Set up Mason
require("mason").setup()
