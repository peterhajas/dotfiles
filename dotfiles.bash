#!/bin/bash

echo "Restowing all apps..."

stow -D stow
stow stow

for dir in */
do
    # Skip the directory named 'nix'
    if [ "$dir" == "nix/" ]; then
        echo "Skipping $dir"
        continue
    fi

    if [ ! -e "$dir/install.yml" ]; then
        echo Unstowing $dir
        stow -D $dir
        echo Restowing $dir
        stow $dir
    else
        ansible-playbook $dir/install.yml
    fi
done

