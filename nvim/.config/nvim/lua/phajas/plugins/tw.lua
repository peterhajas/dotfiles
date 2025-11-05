-- TiddlyWiki plugin configuration

local tw = require("tw")

tw.setup({
  wiki_path = vim.env.HOME .. "/dotfiles/tiddlywiki/wiki.html",
  tw_binary = vim.env.HOME .. "/dotfiles/tiddlywiki/bin/tw",
  auto_init = true,  -- Automatically create wiki if it doesn't exist
  keybindings = {
    edit = "<leader>tw",  -- Telescope tiddler picker
    grep = "<leader>tg",  -- Search tiddler content
  }
})
