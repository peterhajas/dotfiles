# Shell

## ~/bin is where personal executables are stored
for dir in (find -L ~/bin -type d)
    fish_add_path $dir
end

## ~/.bitbar/plugins is where bitbar plugs are stored
fish_add_path ~/.bitbar/plugins

## /usr/local/bin is where brew installs stuff
fish_add_path /usr/local/bin

# Editor

## Set my editor to vim
set -gx EDITOR (which nvim)

# Abbreviations
if type -q abbrev
    abbrev
end

# Shell management

## Set LC_ALL for unicode detection in Ubuntu
## This is from (https://github.com/fish-shell/fish-shell/issues/2126)
set LC_ALL "en_US.utf8"

# Tool configuration
config_editor_aliases

alias mutt neomutt

fish_add_path /opt/homebrew/bin
fish_add_path /opt/homebrew/sbin

# Variables

## AI
export GGML_METAL_PATH_RESOURCES=~/.models/

# uv
fish_add_path "/Users/phajas/.local/bin"

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
