#!/bin/sh

PLATFORM_NAME=`uname`

if [ "$PLATFORM_NAME" == "Darwin" ]; then
    echo "Detected OS X install, proceeding with OS X setup..."
    bash osx_update.bash
else
    echo "Detected Linux install, proceeding with Linux setup..."
    bash linux_update.bash
fi

echo "Installing python libraries..."

sh python_dependencies.sh

echo "Installing ruby libraries..."

sh ruby_dependencies.sh

bash dotfiles.bash

echo "Updating submodules..."
git submodule init
git submodule update
git submodule foreach git pull origin master
