#!/bin/sh

PLATFORM_NAME=`uname`

if [ "$PLATFORM_NAME" = "Darwin" ]; then
    echo "Detected OS X install, proceeding with OS X setup..."
    bash osx_update.bash
else
    echo "Detected Linux install, proceeding with Linux setup..."
    bash linux_update.bash
fi

echo "Setting up dotfiles with Ansible..."
ansible-playbook setup.yml

echo "Updating submodules..."
git submodule init
git submodule update
git submodule foreach git pull origin master
