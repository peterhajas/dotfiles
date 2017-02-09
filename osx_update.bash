#!/bin/sh

echo "Installing Homebrew..."

if which brew 2>/dev/null 1>/dev/null; then
    echo "Homebrew already installed."
else
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo "Installing Homebrew software..."

echo "Homebrew: Installing utilities..."

bash osx_homebrew.bash

echo "Homebrew: Installing Cask apps..."

bash osx_cask.bash

echo "Finalizing Homebrew configuration..."

brew update
brew upgrade
brew cleanup
brew cask cleanup
brew analytics off

echo "Configuring OS X settings..."

bash osx.bash
