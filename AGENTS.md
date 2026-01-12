# dotfiles

This repository uses GNU stow to put files in place.

* ALWAYS edit stuff in here, rather than relative to home. For example, edit ~/dotfiles/nvim/.config/nvim, NOT ~/.config/nvim
* DO NOT leave files in child directories that will show up in ~ unless you want them to be. For example, fish/readme.md will put a readme.md in ~/dotfiles
* DO NOT leave files in child directories that will show up in ~ unless you want them to be. For example, fish/readme.md will put a readme.md in ~/dotfiles - this is WRONG
* Note that many files are in hidden directories (that start with a `.`). DO NOT use tools that don't search these by default, like `rg`
