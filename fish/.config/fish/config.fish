# Shell

## ~/bin is where personal executables are stored
set PATH $PATH (find -L ~/bin -type d)

## ~/.bitbar/plugins is where bitbar plugs are stored
set PATH $PATH ~/.bitbar/plugins

## /usr/local/bin is where brew installs stuff
set PATH /usr/local/bin $PATH;

# Editor

## Set my editor to vim
set EDITOR (which nvim)

# Abbreviations
abbrev

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

## Vimwiki stuff
set -x vimwiki_path ~/.vimwiki
set -x vimwiki_projects_path $vimwiki_path/projects.md

## AI
export GGML_METAL_PATH_RESOURCES=~/.models/
