# Shell

## ~/bin is where personal executables are stored

set PATH $PATH ~/bin;

## /usr/local/bin is where brew installs stuff

set PATH /usr/local/bin $PATH;

# Editor

## Alias `mate` to `mvim`, because muscle memory is strong

alias mate mvim

# Shell management

## Easily open this file

alias confedit "mate ~/.config/fish/config.fish"

# Set a greeting

set fish_greeting hello

# Tool configuration

config_editor_aliases
config_diff_merge_tool

