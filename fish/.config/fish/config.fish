# Shell

## Homebrew (must come before other PATH additions so brew shadows /usr/local)
fish_add_path /opt/homebrew/bin
fish_add_path /opt/homebrew/sbin

## ~/bin is where personal executables are stored
fish_add_path ~/bin

## ~/.bitbar/plugins is where bitbar plugs are stored
fish_add_path ~/.bitbar/plugins

## /usr/local/bin is where brew installs stuff
fish_add_path /usr/local/bin

# Editor

## Set my editor to vim
set -gx EDITOR nvim

# Abbreviations
if type -q abbrev
    abbrev
end

# Shell management

## Set LC_ALL for unicode detection in Ubuntu
## This is from (https://github.com/fish-shell/fish-shell/issues/2126)
set -gx LC_ALL en_US.UTF-8

# Tool configuration
config_editor_aliases

alias mutt neomutt

# Variables

## AI
export GGML_METAL_PATH_RESOURCES=~/.models/

# uv
fish_add_path "/Users/phajas/.local/bin"

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
