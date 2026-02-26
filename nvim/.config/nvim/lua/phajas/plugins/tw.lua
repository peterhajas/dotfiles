-- TiddlyWiki plugin configuration

local tw = require("tw")

tw.setup({
  wiki_path = vim.env.HOME .. "/phajas-wiki/phajas-wiki.html",
  tw_binary = vim.env.HOME .. "/dotfiles/tiddlywiki/bin/tw",
  auto_open_wiki_files = true,  -- Open TiddlyWiki picker when opening .html wiki files
  keybindings = {
    edit            = "<leader>tw",  -- Telescope tiddler picker
    grep            = "<leader>tg",  -- Search tiddler content
    new             = "<leader>tn",  -- New tiddler
    journal_today   = "<leader>tj",  -- Today's journal
    sidebar_toggle  = "<leader>s",   -- Toggle sidebar (same as nvim-tree)
  }
})
