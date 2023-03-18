KEYCODE=$((17+$SID))
osascript -e "tell application \"System Events\" to key code $KEYCODE using option down"
