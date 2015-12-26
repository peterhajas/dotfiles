#!/bin/sh

windowName=`osascript -e "tell application (path to frontmost application as text) to get the name of the front window" 2>/dev/null`

echo $windowName | tr -d '\n'
