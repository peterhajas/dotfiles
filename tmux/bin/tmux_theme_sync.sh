#!/bin/bash

# tmux-theme-sync.sh
# Automatically sync tmux theme with macOS appearance

# Get current macOS appearance
appearance=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")

if [[ "$appearance" == "Dark" ]]; then
    # Modus Vivendi (Dark) colors
    tmux set-option -g status-style fg='#ffffff',bg='#000000'
    tmux set-option -g window-status-style fg='#ffffff',bg='#000000'
    tmux set-option -g window-status-current-style fg='#000000',bg='#00d3d0'
    tmux set-option -g message-style fg='#ffffff',bg='#000000'
    tmux set-option -g pane-border-style fg='#2a2a2a'
    tmux set-option -g pane-active-border-style fg='#00d3d0'
else
    # Modus Operandi (Light) colors
    tmux set-option -g status-style fg='#000000',bg='#ffffff'
    tmux set-option -g window-status-style fg='#000000',bg='#ffffff'
    tmux set-option -g window-status-current-style fg='#ffffff',bg='#0031a9'
    tmux set-option -g message-style fg='#000000',bg='#ffffff'
    tmux set-option -g pane-border-style fg='#c6c6c6'
    tmux set-option -g pane-active-border-style fg='#0031a9'
fi

# Refresh tmux display
tmux refresh-client
