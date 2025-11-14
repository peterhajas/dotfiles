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
    {'numToStr/Comment.nvim'},
    {'tpope/vim-surround'},
    {'tpope/vim-unimpaired'},

    {'mbbill/undotree'},
    {'tpope/vim-dadbod'},
    {'kristijanhusak/vim-dadbod-ui'},
    -- I know, I know. I dig oil.nvim, but this helps with exploring some
    -- projects.
    {'nvim-tree/nvim-tree.lua'},

    {'folke/zen-mode.nvim'},

    {'nvim-telescope/telescope.nvim', tag = '0.1.3', dependencies = {
        'nvim-lua/plenary.nvim',
        {'nvim-telescope/telescope-fzf-native.nvim', build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release'},
    }},

    {'stevearc/oil.nvim'},

    {'nvim-treesitter/nvim-treesitter', cmd = {'TSUpdate'}},
    {'nvim-treesitter/nvim-treesitter-context'},

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
        'hrsh7th/cmp-buffer',
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-nvim-lua',
        'hrsh7th/cmp-path',
        'rafamadriz/friendly-snippets',
        'saadparwaiz1/cmp_luasnip',
    }},

    -- Debugging
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            "rcarriga/nvim-dap-ui",
            "nvim-neotest/nvim-nio", -- required for dap-ui
            "theHamsta/nvim-dap-virtual-text",
            "mfussenegger/nvim-dap-python",
        },
    },

    -- Markdown Stuff
    -- Tables
    {'dhruvasagar/vim-table-mode'},

    -- Harpoon
    {'theprimeagen/harpoon'},

    -- Git
    {'tpope/vim-fugitive'},
    {'lewis6991/gitsigns.nvim'},

    -- UI enhancements
    {'nvim-tree/nvim-web-devicons'},
    {'nvim-lualine/lualine.nvim', dependencies = {
        'nvim-tree/nvim-web-devicons',
    }},
    {'nvim-mini/mini.indentscope', version = false},

    -- Theme
    {"miikanissi/modus-themes.nvim", priority = 1000 },

    -- Local plugins
    { dir = "~/.config/nvim/lua/tw", name = "tw" },
}

local opts = {}

-- Set up Lazy
require("lazy").setup(plugins, opts)

