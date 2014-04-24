#!/bin/sh
echo "Updating pathogen..."

rm vim/.vim/autoload/pathogen.vim
curl -Sso vim/.vim/autoload/pathogen.vim \
    https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim

echo "Updating vim plugins"
git submodule init
git submodule update
