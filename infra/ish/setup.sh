#!/bin/sh
echo "=== doing apk update..."
apk update
echo "=== doing apk upgrade..."
apk upgrade
echo "=== installing neovim..."
apk add neovim
apk add neovim-doc
echo "=== installing git..."
apk add git
apk add openssh
echo "=== cloning repo..."
git clone peterhajas.com:phajas-wiki ~/phajas-wiki
