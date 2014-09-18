#!/bin/sh

echo "Installing Homebrew..."
if which brew 2>/dev/null 1>/dev/null; then
    echo "Homebrew already installed."
else
    ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
fi

echo "Installing Homebrew software..."

echo "Homebrew: Installing utilities..."

brew install fish
brew install vim
brew install stow
brew install tmux
brew install reattach-to-user-namespace
brew install ctags --HEAD
brew install hg
brew install lighttpd
brew install wget
brew install htop
brew install fortune
brew install wine
brew install sloccount
brew install datamash

echo "Homebrew: Installing Cask apps..."

brew install caskroom/cask/brew-cask
brew cask install google-chrome
brew cask install macvim
brew cask install spotify
brew cask install bartender
brew cask install flux
brew cask install keyboard-maestro
brew cask install keyremap4macbook
brew cask install dropbox
brew cask install slate
brew cask install vlc
brew cask install audacity
brew cask install textexpander
brew cask install sketch
brew cask install kaleidoscope
brew cask install xquartz
brew cask install hazel
brew cask install hex-fiend

echo "Homebrew: Installing "fun" Cask apps..."

brew cask install steam
brew cask install origin
brew cask install teamspeak-client

echo "Finalizing Homebrew installation..."
brew cask cleanup
brew update
brew doctor

echo "Configuring stow..."
stow -D stow
stow stow

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

echo "Cleaning and updating vim plugins..."
vim -c "NeoBundleClean" -c q
vim -c "NeoBundleUpdate" -c q

echo "Installing YCM..."
sh ~/.vim/bundle/YouCompleteMe/install.sh

echo "Configuring OS X settings..."
bash .osx.bash
