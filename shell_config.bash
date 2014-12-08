#!/bin/bash

SHELLNAME=$(basename $SHELL)

if [ "$SHELLNAME" == "fish" ]
then
    echo "fish found as \$SHELL, doing nothing"
else
    echo "changing shell to fish"
    sudo chsh -s $(which fish) phajas
fi
