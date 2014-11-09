#!/bin/bash

echo "Clearing Karabiner Preferences..."
rm ~/Library/Preferences/org.pqrs.Karabiner.plist

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

