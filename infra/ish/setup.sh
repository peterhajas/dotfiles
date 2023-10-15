#!/bin/sh
echo "doing apk update..."
apk update
echo "doing apk upgrade..."
apk upgrade
echo "installing neovim..."
apk add neovim
apk add neovim-doc
