# Shell

## ~/bin is where personal executables are stored

set PATH $PATH (find -L ~/bin -type d)

## /usr/local/bin is where brew installs stuff

set PATH /usr/local/bin $PATH;

# Editor

## Set my editor to vim

set EDITOR (which vim)

## Alias `mate` to `mvim`, because muscle memory is strong

alias mate mvim

# Shell management

## Easily open this file

alias confedit "mate ~/.config/fish/config.fish"

# Tool configuration

config_editor_aliases
config_diff_merge_tool
