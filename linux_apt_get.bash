#!/bin/sh

# Needed for apt-add-repository
sudo apt-get install software-properties-common python-software-properties

# This is the repo for fish
sudo apt-add-repository ppa:fish-shell/release-2

sudo apt-get update

# From osx_homebrew.bash

sudo apt-get install fish
sudo apt-get install vim
sudo apt-get install stow
sudo apt-get install tmux
sudo apt-get install ctags
sudo apt-get install mercurial
sudo apt-get install lighttpd
sudo apt-get install wget
sudo apt-get install htop
sudo apt-get install wine
sudo apt-get install sloccount
sudo apt-get install datamash
sudo apt-get install lua
sudo apt-get install python
sudo apt-get install postgresql
sudo apt-get install pngcrush
sudo apt-get install mutt
sudo apt-get install urlview
sudo apt-get install contacts
sudo apt-get install tty-clock
sudo apt-get install cmus
sudo apt-get install youtube-dl
sudo apt-get install nethack
sudo apt-get install tree
sudo apt-get install jq
sudo apt-get install ag

# Others:

# No svn by default? Madness!
sudo apt-get install subversion

# No curl either. wat
sudo apt-get install curl

# Inconsolata, a font we use in x
sudo apt-get install ttf-inconsolata
