#!/bin/sh

echo "Installing Homebrew..."
if which brew 2>/dev/null 1>/dev/null; then
    echo "Homebrew already installed."
else
    ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
fi

echo "Executing brewfiles..."

echo "Brewfile: Installing utilities..."
brew bundle homebrew/.brewfile

echo "Brewfile: Installing Cask apps..."
brew bundle homebrew/.caskfile

echo "Brewfile: Installing "fun" Cask apps..."
brew bundle homebrew/.caskfile_fun

echo "Updating pathogen..."
curl -Sso vim/.vim/autoload/pathogen.vim \
    https://raw.github.com/tpope/vim-pathogen/master/autoload/pathogen.vim

echo "Restowing all apps..."
for dir in */
do
    echo Unstowing $dir
    stow -D $dir
    echo Restowing $dir
    stow $dir
done

echo "Updating submodules..."
git submodule init
git submodule update
