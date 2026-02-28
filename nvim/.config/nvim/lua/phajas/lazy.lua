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
    -- Core editing
    { "numToStr/Comment.nvim",
        event = "VeryLazy",
        config = function()
            require("phajas.plugins.comment")
        end,
    },
    { "tpope/vim-surround", event = "VeryLazy" },
    { "tpope/vim-unimpaired", event = "VeryLazy" },

    { "mbbill/undotree",
        keys = { "<leader>u" },
        config = function()
            require("phajas.plugins.undotree")
        end,
    },
    { "tpope/vim-dadbod",
        event = "VeryLazy",
    },
    { "kristijanhusak/vim-dadbod-ui",
        event = "VeryLazy",
        dependencies = { "tpope/vim-dadbod" },
        config = function()
            require("phajas.plugins.dadbod")
        end,
    },

    -- File explorers
    { "nvim-tree/nvim-tree.lua",
        keys = { "<leader>s" },
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("phajas.plugins.nvim-tree")
        end,
    },
    { "stevearc/oil.nvim",
        keys = { "-" },
        cmd = { "Oil", "Beacon" },
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("phajas.plugins.oil")
        end,
    },

    { "folke/zen-mode.nvim",
        keys = { "<leader>;" },
        config = function()
            require("phajas.plugins.zen-mode")
        end,
    },

    { "nvim-telescope/telescope.nvim",
        event = "VeryLazy",
        tag = "0.1.3",
        dependencies = {
            "nvim-lua/plenary.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release" },
        },
        config = function()
            require("phajas.plugins.telescope")
        end,
    },

    { "nvim-treesitter/nvim-treesitter",
        event = { "BufReadPre", "BufNewFile" },
        cmd = { "TSUpdate" },
        config = function()
            require("phajas.plugins.treesitter")
        end,
    },
    { "nvim-treesitter/nvim-treesitter-context",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = { "nvim-treesitter/nvim-treesitter" },
    },

    -- LSP Support
    { "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
        },
        config = function()
            require("phajas.plugins.mason")
        end,
    },
    { "j-hui/fidget.nvim",
        event = "LspAttach",
        config = function()
            require("phajas.plugins.fidget")
        end,
    },

    -- Autocompletion
    { "saghen/blink.cmp",
        event = "InsertEnter",
        dependencies = {
            "L3MON4D3/LuaSnip",
            "rafamadriz/friendly-snippets",
        },
        version = "*",
        config = function()
            require("phajas.plugins.blink")
        end,
    },

    -- Debugging
    { "mfussenegger/nvim-dap",
        event = "VeryLazy",
        dependencies = {
            "rcarriga/nvim-dap-ui",
            "nvim-neotest/nvim-nio", -- required for dap-ui
            "theHamsta/nvim-dap-virtual-text",
        },
        config = function()
            require("phajas.plugins.debug")
        end,
    },
    { "mfussenegger/nvim-dap-python",
        ft = { "python" },
        dependencies = { "mfussenegger/nvim-dap" },
        config = function()
            require("phajas.plugins.debug_python")
        end,
    },

    -- Markdown Stuff
    { "dhruvasagar/vim-table-mode",
        ft = { "markdown", "tiddlywiki" },
        config = function()
            require("phajas.plugins.table-mode")
        end,
    },

    -- Harpoon
    { "theprimeagen/harpoon",
        event = "VeryLazy",
        dependencies = { "nvim-telescope/telescope.nvim" },
        config = function()
            require("phajas.plugins.harpoon")
        end,
    },

    -- Git
    { "tpope/vim-fugitive",
        event = "VeryLazy",
        cmd = { "Git", "G", "Gdiffsplit", "Gvdiffsplit", "Gedit", "Gread", "Gwrite", "Gwq", "Gclog", "Ggrep" },
        config = function()
            require("phajas.plugins.fugitive")
        end,
    },
    { "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("phajas.plugins.gitsigns")
        end,
    },

    -- UI enhancements
    { "nvim-tree/nvim-web-devicons", lazy = true },
    { "nvim-lualine/lualine.nvim",
        event = "VimEnter",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("phajas.plugins.lualine")
        end,
    },
    { "nvim-mini/mini.indentscope",
        event = { "BufReadPre", "BufNewFile" },
        version = false,
        config = function()
            require("phajas.plugins.indentscope")
        end,
    },

    -- Local plugins
    { dir = "~/.config/nvim/lua/tw",
        name = "tw",
        event = "VeryLazy",
        config = function()
            require("phajas.plugins.tw")
        end,
    },
}

local opts = {}

-- Set up Lazy
require("lazy").setup(plugins, opts)
