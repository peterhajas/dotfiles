#!/bin/bash
# Starts my friends-of-X

## Power manager
xfce4-power-manager

## Notification daemon
/usr/lib/xfce4/notifyd/xfce4-notifyd &

## xmodmap
xmodmap ~/.Xmodmap
