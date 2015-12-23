#!/bin/bash

# Global settings

## Set highlight color to orange
defaults write NSGlobalDomain AppleHighlightColor -string ".8156 0.501 .2156"

## Use Graphite color theme
defaults write NSGlobalDomain AppleAquaColorVariant 6

## Use Dark Mode
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

## Show scrollbars when scrolling
defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"

# Finder / File Panels

## Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

## Hide icons for hard drives, servers, and removable media on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false

## Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

## Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

## Hide desktop icons
defaults write com.apple.finder CreateDesktop -bool false

# Dock

## Hide the Dock
defaults write com.apple.dock autohide -bool true

## Make Dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -bool true

# Menu Bar

## Hide the Menu Bar

defaults write "Apple Global Domain" "_HIHideMenuBar" 1

# Desktop / Screensaver

## Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

## Show the ~/Library folder
chflags nohidden ~/Library

## Don’t automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

## Hot corners
# Possible values:
#  0: no-op
#  2: Mission Control
#  3: Show application windows
#  4: Desktop
#  5: Start screen saver
#  6: Disable screen saver
#  7: Dashboard
# 10: Put display to sleep
# 11: Launchpad
# 12: Notification Center

### Top left screen corner: nothing
defaults write com.apple.dock wvous-tl-corner -int 0
defaults write com.apple.dock wvous-tl-modifier -int 0

### Top right screen corner: notification center
defaults write com.apple.dock wvous-tr-corner -int 12
defaults write com.apple.dock wvous-tr-modifier -int 0

### Bottom left screen corner: start screen saver
defaults write com.apple.dock wvous-bl-corner -int 5
defaults write com.apple.dock wvous-bl-modifier -int 0

# Accessibility

## Enable continuous zoom with the pointer
defaults write com.apple.AppleMultitouchTrackpad HIDScrollZoomModifierMask 262144
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad 262144

defaults write com.apple.universalaccess closeViewPanningMode 0
defaults write com.apple.universalaccess closeViewScrollWheelToggle 1

# Safari

## Show the status bar

defaults write com.apple.Safari ShowOverlayStatusBar 1

## Use DuckDuckGo as my search engine
defaults write com.apple.Safari SearchProviderIdentifier "com.duckduckgo"
defaults write com.apple.Safari SearchProviderIdentifierMigratedToSystemPreference -int 0

## Enable Safari’s debug menu
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

## Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

## Add a context menu item for showing the Web Inspector in web views
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

### Set my Startpage as my home page

defaults write com.apple.Safari "HomePage" "file:///Users/phajas/dotfiles/startpage/.startpage/index.html"
defaults write com.apple.Safari "NewTabBehavior" 0
defaults write com.apple.Safari "NewWindowBehavior" 0

### Use custom CSS

defaults write com.apple.Safari "UserStyleSheetEnabled" 1
defaults write com.apple.Safari "UserStyleSheetLocationURLString" "~/dotfiles/cactus/.config/cactus/cactus.css"

killall Finder
killall Safari
killall Dock

