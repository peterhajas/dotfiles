DOCKUTILBIN=~/bin/dockutil/scripts/dockutil
DOCKUTILADD="$DOCKUTILBIN --add"

killall Dock

# First, remove all items from the Dock

$DOCKUTILBIN --remove all

# Then, add in the apps that I prefer to have there:

$DOCKUTILADD /Applications/Mail.app
$DOCKUTILADD /Applications/Safari.app
$DOCKUTILADD ~/Applications/MacVim.app
$DOCKUTILADD /Applications/Utilities/Terminal.app
$DOCKUTILADD /Applications/Tweetbot.app
$DOCKUTILADD ~/Applications/Spotify.app
$DOCKUTILADD /Applications/Messages.app
