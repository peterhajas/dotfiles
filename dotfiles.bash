#!/bin/bash

echo "Restowing all apps..."

stow -D stow
stow stow

for dir in */
do
    echo Unstowing $dir
    stow -D $dir
    echo Restowing $dir
    stow $dir
done

