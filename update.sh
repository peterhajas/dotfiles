#!/bin/sh
echo "Installing Homebrew..."
ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"

echo "Updating pathogen..."
curl -Sso vim/.vim/autoload/pathogen.vim \
    https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim

echo "Updating vim plugins..."
git submodule init
git submodule update
