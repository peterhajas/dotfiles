#!/bin/bash

DOCKUTILBIN=~/bin/dockutil/scripts/dockutil
DOCKUTILADD="$DOCKUTILBIN --add"

killall Dock

# First, remove all items from the Dock

$DOCKUTILBIN --remove all

# Then, add in the apps that I prefer to have there:

$DOCKUTILADD /Applications/Mail.app
$DOCKUTILADD /Applications/Safari.app
$DOCKUTILADD /Applications/Utilities/Terminal.app
$DOCKUTILADD /Applications/Tweetbot.app
$DOCKUTILADD /Applications/Reeder.app
$DOCKUTILADD /Applications/iTunes.app
$DOCKUTILADD /Applications/Photos.app
$DOCKUTILADD /Applications/Messages.app

$DOCKUTILADD '~' --view grid --display stack
$DOCKUTILADD '~/Downloads' --view fan --display stack
