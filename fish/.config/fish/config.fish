# Shell

## ~/bin is where personal executables are stored

set PATH $PATH (find -L ~/bin -type d)

## ~/.bitbar/plugins is where bitbar plugs are stored
set PATH $PATH ~/.bitbar/plugins

## /usr/local/bin is where brew installs stuff

set PATH /usr/local/bin $PATH;

# Editor

## Set my editor to vim

set EDITOR (which vim)

## Alias `mate` to `mvim`, because muscle memory is strong

alias mate mvim

# Abbreviations
abbrev

# Shell management

## Set LC_ALL for unicode detection in Ubuntu
## This is from (https://github.com/fish-shell/fish-shell/issues/2126)

set LC_ALL "en_US.utf8"

## Easily open this file

alias confedit "mate ~/.config/fish/config.fish"

# Tool configuration

config_editor_aliases

alias mutt neomutt

fish_add_path /opt/homebrew/bin
fish_add_path /opt/homebrew/sbin
