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

    {'nvim-telescope/telescope.nvim', tag = '0.1.3', dependencies = {
        'nvim-lua/plenary.nvim',
        {'nvim-telescope/telescope-fzf-native.nvim', build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release'},
    }},

    {'stevearc/oil.nvim'},

    {'nvim-treesitter/nvim-treesitter', cmd = {'TSUpdate'}},
    {'nvim-treesitter/playground'},
    {'nvim-treesitter/nvim-treesitter-context'},

    -- LSP Support
    {'VonHeikemen/lsp-zero.nvim', branch = 'v3.x'};
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

    -- Markdown
    {"iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        build = "cd app && yarn install",
        init = function()
            vim.g.mkdp_filetypes = { "markdown" }
        end,
        ft = { "markdown" },
    },

    -- AI
    {"olimorris/codecompanion.nvim", dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        "hrsh7th/nvim-cmp", -- Optional: For using slash commands and variables in the chat buffer
        "nvim-telescope/telescope.nvim", -- Optional: For using slash commands
        { "stevearc/dressing.nvim", opts = {} }, -- Optional: Improves the default Neovim UI
    },
    config = true
    },

    -- Harpoon
    {'theprimeagen/harpoon'},

    -- Git
    {'tpope/vim-fugitive'},
    {'lewis6991/gitsigns.nvim'},
    -- {'braxtons12/blame_line.nvim'} - disabled

    -- UI enhancements
    {'nvim-lualine/lualine.nvim', dependencies = {
        'nvim-tree/nvim-web-devicons',
    }},
    {'akinsho/bufferline.nvim'},

    -- Visuals
    {'norcalli/nvim-colorizer.lua'},
    {'catppuccin/nvim', priority = 1000 },
}

local opts = {}

-- Set up Lazy
require("lazy").setup(plugins, opts)

